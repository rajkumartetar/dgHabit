// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_model.dart';

class OverlapInfo {
  final bool prevOverlap;
  final DateTime? prevEnd;
  final bool nextOverlap;
  final DateTime? nextStart;
  OverlapInfo({required this.prevOverlap, this.prevEnd, required this.nextOverlap, this.nextStart});
}

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _activitiesCol =>
      _db.collection('users').doc(uid).collection('activities');

  // Create or update an activity
  Future<void> upsertActivity(ActivityModel activity) async {
    await _activitiesCol.doc(activity.activityId).set(activity.toMap());
  }

  // Create a new document id and write the activity
  Future<String> addActivity(ActivityModel activity) async {
    final doc = _activitiesCol.doc();
    await doc.set({...activity.toMap(), 'activity_id': doc.id});
    return doc.id;
  }

  // Insert activity and maintain a continuous day timeline:
  // - Find the immediately previous activity before new.startTime on the same day and set its end_time = new.startTime
  // - If there is an overlap with the next activity, optionally shift or reject (MVP: truncate new.endTime to next.start_time)
  Future<void> insertActivityContinuous(ActivityModel newAct) async {
    final day = DateTime(newAct.startTime.year, newAct.startTime.month, newAct.startTime.day);
    final startOfDay = Timestamp.fromDate(day);
    final endOfDay = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));

    // Find prev activity (same day) where start_time <= new.start
  final prevSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: startOfDay)
        .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(newAct.startTime))
        .orderBy('start_time', descending: true)
        .limit(1)
        .get();

    // Find next activity (same day) where start_time >= new.start
    final nextSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(newAct.startTime))
        .where('start_time', isLessThanOrEqualTo: endOfDay)
        .orderBy('start_time')
        .limit(1)
        .get();

    DateTime adjustedEnd = newAct.endTime;
    if (nextSnap.docs.isNotEmpty) {
      final nextStart = (nextSnap.docs.first.data()['start_time'] as Timestamp).toDate();
      if (adjustedEnd.isAfter(nextStart)) {
        adjustedEnd = nextStart;
      }
    }

    final batch = _db.batch();
    final newDoc = _activitiesCol.doc();
    batch.set(newDoc, {
      ...newAct.toMap(),
      'activity_id': newDoc.id,
      'end_time': Timestamp.fromDate(adjustedEnd),
    });

    if (prevSnap.docs.isNotEmpty) {
      final prevRef = prevSnap.docs.first.reference;
      // Close the gap/overlap: ensure previous ends where the new one starts
      batch.update(prevRef, {'end_time': Timestamp.fromDate(newAct.startTime)});
    }

    await batch.commit();
  }


  // Detect overlaps for a prospective activity
  Future<OverlapInfo> detectOverlaps(ActivityModel act) async {
    final day = DateTime(act.startTime.year, act.startTime.month, act.startTime.day);
    final startOfDay = Timestamp.fromDate(day);
    final endOfDay = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));

    final prevSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: startOfDay)
        .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(act.startTime))
        .orderBy('start_time', descending: true)
        .limit(1)
        .get();
    final nextSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(act.startTime))
        .where('start_time', isLessThanOrEqualTo: endOfDay)
        .orderBy('start_time')
        .limit(1)
        .get();

    DateTime? prevEnd;
    bool prevOverlap = false;
    if (prevSnap.docs.isNotEmpty) {
      prevEnd = (prevSnap.docs.first.data()['end_time'] as Timestamp).toDate();
      prevOverlap = prevEnd.isAfter(act.startTime);
    }

    DateTime? nextStart;
    bool nextOverlap = false;
    if (nextSnap.docs.isNotEmpty) {
      nextStart = (nextSnap.docs.first.data()['start_time'] as Timestamp).toDate();
      nextOverlap = act.endTime.isAfter(nextStart);
    }

    return OverlapInfo(prevOverlap: prevOverlap, prevEnd: prevEnd, nextOverlap: nextOverlap, nextStart: nextStart);
  }

  // Insert with chosen strategies when overlaps exist.
  // If moveNewStartIfPrev is true and there is prev overlap, new.start = prev.end; otherwise trim prev.end = new.start.
  // If moveNextStartIfNext is true and there is next overlap, next.start = new.end; otherwise trim new.end = next.start.
  Future<void> insertActivityWithStrategies(
    ActivityModel act, {
    required bool moveNewStartIfPrev,
    required bool moveNextStartIfNext,
  }) async {
    final day = DateTime(act.startTime.year, act.startTime.month, act.startTime.day);
    final startOfDay = Timestamp.fromDate(day);
    final endOfDay = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));

    final prevSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: startOfDay)
        .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(act.startTime))
        .orderBy('start_time', descending: true)
        .limit(1)
        .get();
    final nextSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(act.startTime))
        .where('start_time', isLessThanOrEqualTo: endOfDay)
        .orderBy('start_time')
        .limit(1)
        .get();

    DateTime start = act.startTime;
    DateTime end = act.endTime;

    final batch = _db.batch();

    if (prevSnap.docs.isNotEmpty) {
      final prev = prevSnap.docs.first;
      final prevEnd = (prev.data()['end_time'] as Timestamp).toDate();
      if (prevEnd.isAfter(start)) {
        if (moveNewStartIfPrev) {
          start = prevEnd;
        } else {
          batch.update(prev.reference, {'end_time': Timestamp.fromDate(start)});
        }
      }
    }

    if (nextSnap.docs.isNotEmpty) {
      final next = nextSnap.docs.first;
      final nextStart = (next.data()['start_time'] as Timestamp).toDate();
      if (end.isAfter(nextStart)) {
        if (moveNextStartIfNext) {
          batch.update(next.reference, {'start_time': Timestamp.fromDate(end)});
        } else {
          end = nextStart;
        }
      }
    }

    final newDoc = _activitiesCol.doc();
    batch.set(newDoc, {
      ...act.toMap(),
      'activity_id': newDoc.id,
      'start_time': Timestamp.fromDate(start),
      'end_time': Timestamp.fromDate(end),
    });

    await batch.commit();
  }

  // Update an activity with continuity by remove+reinsert pattern
  Future<void> updateActivityContinuous(ActivityModel updated) async {
    final ref = _activitiesCol.doc(updated.activityId);
    // Delete and re-insert with a new id to simplify continuity; preserve id by reusing it
    final day = DateTime(updated.startTime.year, updated.startTime.month, updated.startTime.day);
    final startOfDay = Timestamp.fromDate(day);
    final endOfDay = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));

    // prev and next lookups same as insert
    final prevSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: startOfDay)
        .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(updated.startTime))
        .orderBy('start_time', descending: true)
        .limit(1)
        .get();

    final nextSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(updated.startTime))
        .where('start_time', isLessThanOrEqualTo: endOfDay)
        .orderBy('start_time')
        .limit(1)
        .get();

    DateTime adjustedEnd = updated.endTime;
    if (nextSnap.docs.isNotEmpty) {
      final nextStart = (nextSnap.docs.first.data()['start_time'] as Timestamp).toDate();
      if (adjustedEnd.isAfter(nextStart)) {
        adjustedEnd = nextStart;
      }
    }

    final batch = _db.batch();
    // overwrite the doc with same id
    batch.set(ref, {
      ...updated.toMap(),
      'end_time': Timestamp.fromDate(adjustedEnd),
    });
    if (prevSnap.docs.isNotEmpty) {
      final prevRef = prevSnap.docs.first.reference;
      if (prevRef.id != updated.activityId) {
        batch.update(prevRef, {'end_time': Timestamp.fromDate(updated.startTime)});
      }
    }
    await batch.commit();
  }

  // Stream activities ordered by start_time asc
  Stream<List<ActivityModel>> activitiesStream({DateTime? day}) {
    final startOfDay = DateTime(day?.year ?? DateTime.now().year, day?.month ?? DateTime.now().month, day?.day ?? DateTime.now().day);
    final endOfDay = DateTime(startOfDay.year, startOfDay.month, startOfDay.day, 23, 59, 59);

    return _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('start_time')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ActivityModel.fromDoc).toList());
  }

  // Stream activities in a date range [start, end]
  Stream<List<ActivityModel>> activitiesStreamRange({required DateTime start, required DateTime end}) {
    return _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('start_time')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ActivityModel.fromDoc).toList());
  }

  Future<void> deleteActivity(String activityId) async {
    await _activitiesCol.doc(activityId).delete();
  }

  // Get the last end time for today; if no activities yet, return start of today at 00:00
  Future<DateTime> lastEndOfToday() async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final startOfDay = Timestamp.fromDate(day);
    final endOfDay = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));

    final lastSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: startOfDay)
        .where('start_time', isLessThanOrEqualTo: endOfDay)
        .orderBy('start_time', descending: true)
        .limit(1)
        .get();

    if (lastSnap.docs.isNotEmpty) {
      final lastEnd = (lastSnap.docs.first.data()['end_time'] as Timestamp).toDate();
      return lastEnd;
    }
    return DateTime(now.year, now.month, now.day, 0, 0);
  }

  // Append an activity to the end of the current day's timeline.
  // Finds the last activity for the day and starts the new one at its end_time.
  Future<void> appendActivityToToday(ActivityModel base) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final startOfDay = Timestamp.fromDate(day);
    final endOfDay = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));

    final lastSnap = await _activitiesCol
        .where('start_time', isGreaterThanOrEqualTo: startOfDay)
        .where('start_time', isLessThanOrEqualTo: endOfDay)
        .orderBy('start_time', descending: true)
        .limit(1)
        .get();

    DateTime start = DateTime(now.year, now.month, now.day, 0, 0);
    if (lastSnap.docs.isNotEmpty) {
      final lastEnd = (lastSnap.docs.first.data()['end_time'] as Timestamp).toDate();
      start = lastEnd;
    }

    final end = now.isAfter(start) ? now : start.add(const Duration(minutes: 30));
    final activity = ActivityModel(
      activityId: base.activityId,
      activityName: base.activityName,
      startTime: start,
      endTime: end,
      category: base.category,
      source: base.source,
      steps: base.steps,
      screenTimeMinutes: base.screenTimeMinutes,
    );
    await insertActivityContinuous(activity);
  }

  // Simple connectivity diagnostic: write and read a doc
  Future<String> connectivityCheck() async {
    try {
      final diagDoc = _db.collection('users').doc(uid).collection('diagnostics').doc('ping');
      await diagDoc.set({
        'ts': FieldValue.serverTimestamp(),
        'client': 'dgHabit',
      }, SetOptions(merge: true));
      final snap = await diagDoc.get();
      final hasTs = (snap.data()?['ts'] != null);
      return hasTs ? 'Firestore write/read OK' : 'Write OK, read missing ts field';
    } catch (e) {
      return 'Firestore error: $e';
    }
  }

  // ---------- User categories (custom) ----------
  DocumentReference<Map<String, dynamic>> get _prefsDoc =>
      _db.collection('users').doc(uid).collection('meta').doc('prefs');

  Future<List<String>> getUserCategories() async {
    try {
      final snap = await _prefsDoc.get();
      final data = snap.data();
      if (data == null) return <String>[];
      final list = (data['categories'] as List?)?.whereType<String>().toList() ?? <String>[];
      return list;
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> addUserCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await _prefsDoc.set({'categories': FieldValue.arrayUnion([trimmed])}, SetOptions(merge: true));
    } catch (_) {
      // ignore; non-fatal UX
    }
  }

  Future<void> deleteUserCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await _prefsDoc.set({'categories': FieldValue.arrayRemove([trimmed])}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> renameUserCategory({required String from, required String to}) async {
    final f = from.trim();
    final t = to.trim();
    if (f.isEmpty || t.isEmpty) return;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_prefsDoc);
        final data = snap.data() ?? {};
        final list = (data['categories'] as List?)?.whereType<String>().toList() ?? <String>[];
        final set = {...list};
        set.remove(f);
        set.add(t);
        tx.set(_prefsDoc, {'categories': set.toList()}, SetOptions(merge: true));
      });
    } catch (_) {}
  }

  // Count activities that currently use the given category
  Future<int> countActivitiesUsingCategory(String category) async {
    final snap = await _activitiesCol.where('category', isEqualTo: category).get();
    return snap.size;
  }

  // Reassign all activities from one category to another, chunking writes
  Future<void> reassignCategory({required String from, required String to}) async {
    final snap = await _activitiesCol.where('category', isEqualTo: from).get();
    if (snap.docs.isEmpty) return;
    const chunkSize = 400; // Firestore batch limit safety
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final batch = _db.batch();
      final slice = snap.docs.skip(i).take(chunkSize);
      for (final d in slice) {
        batch.update(d.reference, {'category': to});
      }
      await batch.commit();
    }
  }
}
