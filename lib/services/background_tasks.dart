// lib/services/background_tasks.dart
// Background periodic screen-time limit checks using Workmanager (Android).
import 'dart:io' show Platform;
import 'package:workmanager/workmanager.dart' as wm;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dghabit/third_party/usage_stats.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_info_channel.dart';

const String kScreenCheckTask = 'dg_screen_time_check_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  wm.Workmanager().executeTask((task, inputData) async {
    if (task != kScreenCheckTask) return Future.value(true);
    if (!Platform.isAndroid) return Future.value(true);

    try {
      final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('notif_enabled') ?? false;
  final bgEnabled = prefs.getBool('notif_background_screen_check') ?? false;
  final limitMin = prefs.getInt('notif_screen_limit_min') ?? 120;
  final perAppRaw = prefs.getString('notif_per_app_limits');
      if (!(enabled && bgEnabled)) return Future.value(true);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);

      // Compute this app's foreground time today
      Duration used = Duration.zero;
      try {
        final pkg = (await PackageInfo.fromPlatform()).packageName;
        final events = await UsageStats.queryEvents(start, now);
        DateTime? inFg;
        for (final ev in events) {
          if (ev.packageName != pkg) continue;
          final ts = DateTime.fromMillisecondsSinceEpoch(int.tryParse(ev.timeStamp ?? '0') ?? 0);
          final type = ev.eventType ?? '';
          if (type == '1' || type.toLowerCase().contains('foreground')) {
            inFg ??= ts;
          } else if (type == '2' || type.toLowerCase().contains('background')) {
            if (inFg != null) {
              used += ts.difference(inFg);
              inFg = null;
            }
          }
        }
        if (inFg != null) {
          used += now.difference(inFg);
        }
      } catch (_) {
        // If usage not available, bail out gracefully
        return Future.value(true);
      }

      if (used.inMinutes >= limitMin) {
        // Fire a local notification
        final plugin = FlutterLocalNotificationsPlugin();
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        try {
          await plugin.initialize(initSettings);
        } catch (_) {}
        const androidDetails = AndroidNotificationDetails(
          'dg_screen_limit',
          'Screen limit',
          channelDescription: 'Automatic screen-time limit alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
        const details = NotificationDetails(android: androidDetails);
        String appLabel = 'This app';
        try {
          final info = await PackageInfo.fromPlatform();
          appLabel = info.appName.isNotEmpty ? info.appName : appLabel;
        } catch (_) {}
        try {
          await plugin.show(
            300,
            '$appLabel screen time limit',
            "You've used ${limitMin.toString()}+ minutes today in $appLabel.",
            details,
          );
        } catch (_) {}
      }

      // Per-app checks
      if (perAppRaw != null && perAppRaw.trim().isNotEmpty) {
        final Map<String, int> perApp = {};
        for (final part in perAppRaw.split(',')) {
          final idx = part.indexOf(':');
          if (idx <= 0) continue;
          final k = part.substring(0, idx);
          final v = int.tryParse(part.substring(idx + 1)) ?? 0;
          if (k.isNotEmpty && v > 0) perApp[k] = v;
        }
        if (perApp.isNotEmpty) {
          final stats = await UsageStats.queryUsageStats(start, now);
          final map = <String, int>{};
          for (final s in stats) {
            final pkg = s.packageName ?? '';
            if (!perApp.containsKey(pkg)) continue;
            final ms = int.tryParse(s.totalTimeInForeground ?? '0') ?? 0;
            map[pkg] = (map[pkg] ?? 0) + ms;
          }
          final plugin = FlutterLocalNotificationsPlugin();
          const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
          const initSettings = InitializationSettings(android: androidInit);
          try { await plugin.initialize(initSettings); } catch (_) {}
          Map<String, String> names = {};
          try {
            final infoMap = await AppInfoChannel().fetchMany(perApp.keys);
            names = { for (final e in infoMap.entries) e.key : e.value.name };
          } catch (_) {}
          for (final entry in perApp.entries) {
            final pkg = entry.key;
            final limit = entry.value;
            final ms = map[pkg] ?? 0;
            if (Duration(milliseconds: ms).inMinutes >= limit) {
              const androidDetails = AndroidNotificationDetails(
                'dg_app_limit',
                'App limit',
                channelDescription: 'Per-app screen-time alerts',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              );
              const details = NotificationDetails(android: androidDetails);
              final id = 1000 + pkg.hashCode.abs();
              final human = names[pkg] ?? pkg;
              try {
                await plugin.show(
                  id,
                  'Limit reached for $human',
                  "You've used $human for ${Duration(milliseconds: ms).inMinutes}+ minutes today.",
                  details,
                );
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    return Future.value(true);
  });
}

Future<void> initWorkmanager() async {
  if (!Platform.isAndroid) return;
  try {
    await wm.Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  } catch (_) {}
}

Future<void> ensureScheduledFromPrefs() async {
  if (!Platform.isAndroid) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_enabled') ?? false;
    final bgEnabled = prefs.getBool('notif_background_screen_check') ?? false;
    final limitMin = prefs.getInt('notif_screen_limit_min') ?? 120;
    if (enabled && bgEnabled && limitMin > 0) {
      await scheduleScreenCheckPeriodic();
    } else {
      await cancelScreenCheck();
    }
  } catch (_) {}
}

Future<void> scheduleScreenCheckPeriodic() async {
  if (!Platform.isAndroid) return;
  try {
    // Periodic constraint on Android is minimum 15 minutes
    await wm.Workmanager().registerPeriodicTask(
      'dg_screen_check',
      kScreenCheckTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.update,
    );
  } catch (_) {}
}

Future<void> cancelScreenCheck() async {
  if (!Platform.isAndroid) return;
  try {
    await wm.Workmanager().cancelByUniqueName('dg_screen_check');
  } catch (_) {}
}
