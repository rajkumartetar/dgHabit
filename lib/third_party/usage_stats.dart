// Minimal local stub replacement for the unmaintained usage_stats plugin.
// This allows the app to build (including release) while gracefully degrading
// screen time features. On Android, grantUsagePermission will open the Usage
// Access settings using our SystemChannel. All query methods return empty lists.

import 'dart:async';
import 'dart:io';

import 'package:dghabit/services/system_channel.dart';

class UsageStats {
  // Return whether Usage Access is granted. We can't check without native code,
  // so return false to prompt the UI to offer opening settings.
  static Future<bool> checkUsagePermission() async {
    if (!Platform.isAndroid) return false;
    // TODO: Implement a real check via platform channel if needed.
    return false;
  }

  // Open the Usage Access settings via our existing system channel.
  static Future<void> grantUsagePermission() async {
    await SystemChannel().openUsageAccessSettings();
  }

  static Future<List<UsageInfo>> queryUsageStats(DateTime start, DateTime end) async {
    // Not available in stub; return empty -> callers will show "No data".
    return <UsageInfo>[];
  }

  static Future<List<UsageEvent>> queryEvents(DateTime start, DateTime end) async {
    return <UsageEvent>[];
  }
}

class UsageInfo {
  final String? packageName;
  final String? totalTimeInForeground; // milliseconds, as string to match plugin API
  UsageInfo({this.packageName, this.totalTimeInForeground});
}

class UsageEvent {
  final String? packageName;
  final String? timeStamp; // milliseconds since epoch, string
  final String? eventType; // string label or numeric code
  UsageEvent({this.packageName, this.timeStamp, this.eventType});
}
