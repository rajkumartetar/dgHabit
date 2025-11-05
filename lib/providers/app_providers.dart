// lib/providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/sensor_service.dart';
import '../services/notification_service.dart';

// Global providers used across screens
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

// Sensor service provider
final sensorServiceProvider = Provider<SensorService>((ref) => SensorService());

// Notifications service provider
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

// Simple notification preferences stored in SharedPreferences
class NotificationPrefs {
	final bool enabled;
	final int inactivityHours; // 1,2,3...
	final int screenTimeLimitMinutes; // limit for this app (manual check)
	final bool backgroundScreenChecks; // periodic background check (Android)
	final Map<String, int> perAppLimits; // packageName -> minutes
	const NotificationPrefs({
		required this.enabled,
		required this.inactivityHours,
		required this.screenTimeLimitMinutes,
		required this.backgroundScreenChecks,
		required this.perAppLimits,
	});

	NotificationPrefs copyWith({bool? enabled, int? inactivityHours, int? screenTimeLimitMinutes, bool? backgroundScreenChecks, Map<String, int>? perAppLimits}) => NotificationPrefs(
				enabled: enabled ?? this.enabled,
				inactivityHours: inactivityHours ?? this.inactivityHours,
				screenTimeLimitMinutes: screenTimeLimitMinutes ?? this.screenTimeLimitMinutes,
				backgroundScreenChecks: backgroundScreenChecks ?? this.backgroundScreenChecks,
				perAppLimits: perAppLimits ?? this.perAppLimits,
			);
}

class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
	static const _kEnabled = 'notif_enabled';
	static const _kHours = 'notif_inactivity_hours';
	static const _kScreenLimit = 'notif_screen_limit_min';
  static const _kScreenBg = 'notif_background_screen_check';
	static const _kPerApp = 'notif_per_app_limits';

	@override
	NotificationPrefs build() {
		_load();
		return const NotificationPrefs(enabled: false, inactivityHours: 2, screenTimeLimitMinutes: 120, backgroundScreenChecks: false, perAppLimits: {});
	}

	Future<void> _load() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			state = NotificationPrefs(
				enabled: prefs.getBool(_kEnabled) ?? false,
				inactivityHours: prefs.getInt(_kHours) ?? 2,
				screenTimeLimitMinutes: prefs.getInt(_kScreenLimit) ?? 120,
				backgroundScreenChecks: prefs.getBool(_kScreenBg) ?? false,
				perAppLimits: _decodePerApp(prefs.getString(_kPerApp)),
			);
		} catch (_) {}
	}

	Future<void> setEnabled(bool v) async {
		state = state.copyWith(enabled: v);
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setBool(_kEnabled, v);
		} catch (_) {}
	}

	Future<void> setInactivityHours(int h) async {
		state = state.copyWith(inactivityHours: h);
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setInt(_kHours, h);
		} catch (_) {}
	}

	Future<void> setScreenTimeLimit(int min) async {
		state = state.copyWith(screenTimeLimitMinutes: min);
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setInt(_kScreenLimit, min);
		} catch (_) {}
	}

	Future<void> setBackgroundScreenChecks(bool v) async {
		state = state.copyWith(backgroundScreenChecks: v);
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setBool(_kScreenBg, v);
		} catch (_) {}
	}

	Future<void> setPerAppLimit(String packageName, int minutes) async {
		final map = Map<String, int>.from(state.perAppLimits);
		map[packageName] = minutes;
		state = state.copyWith(perAppLimits: map);
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString(_kPerApp, _encodePerApp(map));
		} catch (_) {}
	}

	Future<void> removePerAppLimit(String packageName) async {
		final map = Map<String, int>.from(state.perAppLimits);
		map.remove(packageName);
		state = state.copyWith(perAppLimits: map);
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString(_kPerApp, _encodePerApp(map));
		} catch (_) {}
	}

	String _encodePerApp(Map<String, int> map) => map.entries.map((e) => '${e.key}:${e.value}').join(',');
	Map<String, int> _decodePerApp(String? raw) {
		if (raw == null || raw.trim().isEmpty) return {};
		final out = <String, int>{};
		for (final part in raw.split(',')) {
			final idx = part.indexOf(':');
			if (idx <= 0) continue;
			final k = part.substring(0, idx);
			final v = int.tryParse(part.substring(idx + 1)) ?? 0;
			if (k.isNotEmpty && v > 0) out[k] = v;
		}
		return out;
	}
}

final notificationPrefsProvider = NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
	NotificationPrefsNotifier.new,
);


// Theme mode provider for in-app toggle
class ThemeModeNotifier extends Notifier<ThemeMode> {
	static const _key = 'theme_mode';
	@override
	ThemeMode build() {
		// kick off async load; default to system now
		_load();
		return ThemeMode.system;
	}

	Future<void> _load() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			final val = prefs.getString(_key);
			if (val != null) {
				switch (val) {
					case 'light':
						state = ThemeMode.light;
						break;
					case 'dark':
						state = ThemeMode.dark;
						break;
					default:
						state = ThemeMode.system;
				}
			}
		} catch (_) {}
	}

	Future<void> set(ThemeMode value) async {
		state = value;
		try {
			final prefs = await SharedPreferences.getInstance();
			final str = value == ThemeMode.light
					? 'light'
					: value == ThemeMode.dark
							? 'dark'
							: 'system';
			await prefs.setString(_key, str);
		} catch (_) {}
	}
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
