// lib/services/sensor_service.dart
// Thin wrapper to fetch steps and screen time on Android.
import 'dart:async';
import 'dart:io';
import 'package:pedometer/pedometer.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SensorService {
  StreamSubscription<StepCount>? _stepSub;
  static const _stepsBaselineKeyPrefix = 'steps_baseline_'; // key + yyyymmdd

  // Listen to step counts (cumulative since boot). Returns stream of StepCount
  Stream<StepCount>? startStepStream({Function(StepCount)? onData, Function? onError}) {
    if (!Platform.isAndroid) return null;
    final stream = Pedometer.stepCountStream;
    _stepSub = stream.listen(
      (event) {
        if (onData != null) onData(event);
      },
      onError: (e) {
        if (onError != null) onError(e);
      },
      cancelOnError: false,
    );
    return stream;
  }

  void stopStepStream() {
    _stepSub?.cancel();
    _stepSub = null;
  }

  // Compute today's steps using the cumulative counter baseline stored per day.
  // Returns null if unavailable.
  Future<int?> getTodaySteps() async {
    if (!Platform.isAndroid) return null;
    try {
      final evt = await Pedometer.stepCountStream.first.timeout(const Duration(seconds: 3));
      final stepsNow = evt.steps;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final key = '$_stepsBaselineKeyPrefix${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      int? baseline = prefs.getInt(key);
      // If baseline not present or day changed, initialize baseline to the first observed value for today.
      if (baseline == null) {
        await prefs.setInt(key, stepsNow);
        baseline = stepsNow;
      }
      final delta = stepsNow - baseline;
      return delta >= 0 ? delta : 0;
    } catch (_) {
      return null;
    }
  }

  // Get screen time in milliseconds between [start] and [end]
  // Requires user to grant Usage Access permission in Settings.
  Future<Duration?> getScreenTime(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return null;
    try {
      final events = await UsageStats.queryUsageStats(start, end);
      // Sum total foreground time from each app
      int totalMs = 0;
      for (final e in events) {
        final ms = int.tryParse(e.totalTimeInForeground ?? '0') ?? 0;
        totalMs += ms;
      }
      return Duration(milliseconds: totalMs);
    } catch (_) {
      return null;
    }
  }

  // Get foreground time for this app bundle specifically (Android).
  Future<Duration?> getThisAppScreenTime(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return null;
    try {
      final pkg = (await PackageInfo.fromPlatform()).packageName;
      final events = await UsageStats.queryEvents(start, end);
      // We consider ActivityResumed (MOVE_TO_FOREGROUND) to ActivityPaused (MOVE_TO_BACKGROUND)
      DateTime? inForegroundAt;
      int totalMs = 0;
      for (final ev in events) {
        if (ev.packageName != pkg) continue;
        final ts = DateTime.fromMillisecondsSinceEpoch(int.tryParse(ev.timeStamp ?? '0') ?? 0);
        final type = ev.eventType ?? '';
        if (type == '1' /*MOVE_TO_FOREGROUND*/ || type.toLowerCase().contains('foreground')) {
          inForegroundAt ??= ts;
        } else if (type == '2' /*MOVE_TO_BACKGROUND*/ || type.toLowerCase().contains('background')) {
          if (inForegroundAt != null) {
            totalMs += ts.difference(inForegroundAt).inMilliseconds;
            inForegroundAt = null;
          }
        }
      }
      // If still in foreground at end
      if (inForegroundAt != null) {
        totalMs += end.difference(inForegroundAt).inMilliseconds;
      }
      return Duration(milliseconds: totalMs);
    } catch (_) {
      return null;
    }
  }

  // Get per-app foreground time map between [start, end], packageName -> Duration
  Future<Map<String, Duration>?> getPerAppScreenTimeMap(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return null;
    try {
      final stats = await UsageStats.queryUsageStats(start, end);
      final map = <String, Duration>{};
      for (final s in stats) {
        final pkg = s.packageName ?? '';
        if (pkg.isEmpty) continue;
        final ms = int.tryParse(s.totalTimeInForeground ?? '0') ?? 0;
        if (ms <= 0) continue;
        map[pkg] = Duration(milliseconds: ms);
      }
      return map;
    } catch (_) {
      return null;
    }
  }
}
