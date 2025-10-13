// lib/providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/sensor_service.dart';

// Global providers used across screens
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

// Sensor service provider
final sensorServiceProvider = Provider<SensorService>((ref) => SensorService());


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
