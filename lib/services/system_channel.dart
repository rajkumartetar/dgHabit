import 'dart:io';
import 'package:flutter/services.dart';

class SystemChannel {
  static const _channel = MethodChannel('com.example.dghabit/system');

  Future<bool> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('openUsageAccessSettings');
      return res == true;
    } catch (_) {
      return false;
    }
  }
}
