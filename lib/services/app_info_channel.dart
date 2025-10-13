import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class AppInfoItem {
  final String package;
  final String name;
  final Uint8List? icon;
  AppInfoItem({required this.package, required this.name, this.icon});
}

class AppInfoChannel {
  static const _channel = MethodChannel('com.example.dghabit/app_info');
  final Map<String, AppInfoItem> _cache = {};

  Future<Map<String, AppInfoItem>> fetchMany(Iterable<String> packages) async {
    final pkgs = packages.toList();
    final missing = pkgs.where((p) => !_cache.containsKey(p)).toList();
    if (Platform.isAndroid && missing.isNotEmpty) {
      try {
        final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppInfos', {
          'packages': missing,
        });
        if (res != null) {
          res.forEach((k, v) {
            final map = (v as Map).cast<String, dynamic>();
            final pkg = k as String;
            final item = AppInfoItem(
              package: pkg,
              name: (map['name'] as String?) ?? pkg,
              icon: map['icon'] as Uint8List?,
            );
            _cache[pkg] = item;
          });
        }
      } catch (_) {
        // ignore; fall back to package ids
      }
    }
    return {
      for (final p in pkgs)
        p: _cache[p] ?? AppInfoItem(package: p, name: p)
    };
  }
}
