// lib/models/activity_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivitySource { manual, auto }

class ActivityModel {
  final String activityId;
  final String activityName;
  final DateTime startTime;
  final DateTime endTime;
  final String category; // Work/Health/Leisure
  final ActivitySource source;
  final int? steps;
  final double? screenTimeMinutes; // optional

  ActivityModel({
    required this.activityId,
    required this.activityName,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.source,
    this.steps,
    this.screenTimeMinutes,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toMap() => {
        'activity_id': activityId,
        'activity_name': activityName,
        'start_time': Timestamp.fromDate(startTime),
        'end_time': Timestamp.fromDate(endTime),
        'category': category,
        'source': source.name,
        'steps': steps,
        'screen_time': screenTimeMinutes,
      };

  factory ActivityModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      activityId: data['activity_id'] ?? doc.id,
      activityName: data['activity_name'] ?? 'Activity',
      startTime: (data['start_time'] as Timestamp).toDate(),
      endTime: (data['end_time'] as Timestamp).toDate(),
      category: data['category'] ?? 'General',
      source: (data['source'] == 'auto') ? ActivitySource.auto : ActivitySource.manual,
      steps: data['steps'],
      screenTimeMinutes: (data['screen_time'] is int)
          ? (data['screen_time'] as int).toDouble()
          : data['screen_time'],
    );
  }
}
