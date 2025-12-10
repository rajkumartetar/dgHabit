// Golden screenshot generator for dgHabit screens.
// Writes images directly to docs/screenshots/individual/*.png
// Run with: flutter test --update-goldens test/generate_screenshots_test.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dghabit/firebase_options.dart';

// App imports
// Use a simple fallback theme to avoid runtime font fetching (GoogleFonts) during golden tests.
// Real app uses AppTheme with GoogleFonts, but network font fetches are blocked in tests.
// import 'package:dghabit/theme/app_theme.dart';
import 'package:dghabit/providers/app_providers.dart';
import 'package:dghabit/models/activity_model.dart';
import 'package:dghabit/screens/splash_screen.dart';
import 'package:dghabit/screens/onboarding_screen.dart';
import 'package:dghabit/screens/home_screen.dart';
import 'package:dghabit/screens/timeline_screen.dart';
import 'package:dghabit/screens/analytics_screen.dart';
import 'package:dghabit/screens/add_activity_screen.dart';
import 'package:dghabit/screens/activity_detail_screen.dart';
import 'package:dghabit/screens/settings_screen.dart';
import 'package:dghabit/screens/permissions_screen.dart';
import 'package:dghabit/screens/category_manager_screen.dart';
import 'package:dghabit/services/firebase_service.dart';
import 'package:dghabit/services/sensor_service.dart';

// ---- Fakes ----
class FakeFirebaseService extends FirebaseService {
  final String _uid;
  final List<ActivityModel> _today;
  final List<ActivityModel> _week;
  final List<String> _categories;

  FakeFirebaseService({
    String uid = 'test-user',
    List<ActivityModel>? today,
    List<ActivityModel>? week,
    List<String>? categories,
  })  : _uid = uid,
        _today = today ?? _sampleToday(),
        _week = week ?? _sampleWeek(),
        _categories = categories ?? const ['Personal','Hygiene','Travel','Work','Fun','Productivity','Growth','Meals'];

  @override
  String get uid => _uid;

  @override
  Stream<List<ActivityModel>> activitiesStream({DateTime? day}) {
    final d = DateTime(day?.year ?? DateTime.now().year, day?.month ?? DateTime.now().month, day?.day ?? DateTime.now().day);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final reqKey = DateTime(d.year, d.month, d.day);
    if (reqKey == todayKey) {
      return Stream.value(_today);
    }
    // Yesterday: provide a trimmed subset
    return Stream.value(_today.take(3).toList());
  }

  @override
  Stream<List<ActivityModel>> activitiesStreamRange({required DateTime start, required DateTime end}) {
    return Stream.value(_week);
  }

  @override
  Future<List<String>> getUserCategories() async => _categories;

  // No-ops for mutating methods used only by UI actions not triggered in screenshots
  @override
  Future<void> deleteActivity(String activityId) async {}
  @override
  Future<void> upsertActivity(ActivityModel activity) async {}
  @override
  Future<void> insertActivityContinuous(ActivityModel newAct) async {}
  @override
  Future<OverlapInfo> detectOverlaps(ActivityModel act) async => OverlapInfo(prevOverlap: false, nextOverlap: false);
  @override
  Future<void> insertActivityWithStrategies(ActivityModel act, {required bool moveNewStartIfPrev, required bool moveNextStartIfNext}) async {}
  @override
  Future<void> appendActivityToToday(ActivityModel base) async {}
  @override
  Future<DateTime> lastEndOfToday() async => DateTime.now();
  @override
  Future<int> countActivitiesUsingCategory(String category) async => 0;
  @override
  Future<void> reassignCategory({required String from, required String to}) async {}
  @override
  Future<void> deleteUserCategory(String name) async {}
  @override
  Future<void> renameUserCategory({required String from, required String to}) async {}
  @override
  Future<void> addUserCategory(String name) async {}
}

class FakeSensorService extends SensorService {
  @override
  Future<int?> getTodaySteps() async => 8234;

  @override
  Future<Map<String, Duration>?> getPerAppScreenTimeMap(DateTime start, DateTime end) async {
    // Richer mock data for analytics (Top apps chart)
    return {
      'com.whatsapp': const Duration(minutes: 52),
      'com.instagram.android': const Duration(minutes: 41),
      'com.android.chrome': const Duration(minutes: 36),
      'com.google.android.youtube': const Duration(minutes: 33),
      'com.google.android.gm': const Duration(minutes: 18),
      'com.snapchat.android': const Duration(minutes: 12),
      'org.telegram.messenger': const Duration(minutes: 10),
      'com.spotify.music': const Duration(minutes: 8),
    };
  }

  @override
  Future<Duration?> getThisAppScreenTime(DateTime start, DateTime end) async => const Duration(minutes: 15);
}

class FakeNotif extends NotificationPrefsNotifier {
  @override
  NotificationPrefs build() {
    // Return a fixed value; skip SharedPreferences
    return const NotificationPrefs(
      enabled: true,
      inactivityHours: 2,
      screenTimeLimitMinutes: 120,
      backgroundScreenChecks: false,
      perAppLimits: {},
    );
  }
}

class FakeTheme extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

ProviderScope _scoped({required Widget child}) {
  return ProviderScope(
    overrides: [
      firebaseServiceProvider.overrideWithValue(FakeFirebaseService()),
      sensorServiceProvider.overrideWithValue(FakeSensorService()),
      notificationPrefsProvider.overrideWith(FakeNotif.new),
      themeModeProvider.overrideWith(FakeTheme.new),
    ],
    child: child,
  );
}

Widget _app(Widget home) {
  final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DD4BF)));
  return _scoped(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme, // default fonts (no network)
      ),
      home: TickerMode(enabled: false, child: home), // disable animations for deterministic goldens
      routes: {
        '/auth': (_) => const Scaffold(body: Center(child: Text('Auth'))),
        '/onboarding': (_) => const OnboardingScreen(),
      },
    ),
  );
}

Widget _appDark(Widget home) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF14B8A6),
      brightness: Brightness.dark,
    ),
  );
  return _scoped(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme,
      ),
      home: TickerMode(enabled: false, child: home),
      routes: {
        '/auth': (_) => const Scaffold(body: Center(child: Text('Auth'))),
        '/onboarding': (_) => const OnboardingScreen(),
      },
    ),
  );
}

Future<void> _setSurfaceSize(WidgetTester tester) async {
  const size = Size(390, 844); // phone-like size
  tester.binding.window.physicalSizeTestValue = size * 2.0; // DPR 2
  tester.binding.window.devicePixelRatioTestValue = 2.0;
  addTearDown(() {
    tester.binding.window.clearPhysicalSizeTestValue();
    tester.binding.window.clearDevicePixelRatioTestValue();
  });
}

void main() {
  // Use the stock configuration; tests explicitly pump.
  GoldenToolkit.runWithConfiguration(() {
    setUpAll(() async {
      await loadAppFonts();
      TestWidgetsFlutterBinding.ensureInitialized();
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {}
    });

  testGoldens('splash', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const SplashScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/splash');
    // Let any scheduled timers (navigation delay) complete to avoid pending timers on teardown.
    await tester.pump(const Duration(seconds: 2));
  });

  testGoldens('splash_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const SplashScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/splash_dark');
    await tester.pump(const Duration(seconds: 2));
  });

  testGoldens('onboarding', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const OnboardingScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/onboarding');
  });

  testGoldens('onboarding_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const OnboardingScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/onboarding_dark');
  });

  testGoldens('home', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/home');
  });

  testGoldens('home_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/home_dark');
  });

  testGoldens('timeline', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const Scaffold(appBar: null, body: TimelineScreen())));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/timeline');
  });

  testGoldens('timeline_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const Scaffold(appBar: null, body: TimelineScreen())));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/timeline_dark');
  });

  // Duplicates with explicit naming to showcase data-rich variants in docs
  testGoldens('timeline_with_data', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const Scaffold(appBar: null, body: TimelineScreen())));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/timeline_with_data');
  });

  testGoldens('timeline_with_data_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const Scaffold(appBar: null, body: TimelineScreen())));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/timeline_with_data_dark');
  });

  testGoldens('analytics', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const Scaffold(appBar: null, body: AnalyticsScreen(forceIsAndroid: true))));
    await tester.pump(const Duration(milliseconds: 400));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/analytics');
  });

  testGoldens('analytics_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const Scaffold(appBar: null, body: AnalyticsScreen(forceIsAndroid: true))));
    await tester.pump(const Duration(milliseconds: 400));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/analytics_dark');
  });

  // with_data named duplicates for documentation
  testGoldens('analytics_with_data', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const Scaffold(appBar: null, body: AnalyticsScreen(forceIsAndroid: true)))) ;
    await tester.pump(const Duration(milliseconds: 400));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/analytics_with_data');
  });

  testGoldens('analytics_with_data_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const Scaffold(appBar: null, body: AnalyticsScreen(forceIsAndroid: true)))) ;
    await tester.pump(const Duration(milliseconds: 400));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/analytics_with_data_dark');
  });

  testGoldens('add_activity', (tester) async {
    await _setSurfaceSize(tester);
    final startAt = DateTime(2025, 11, 5, 9, 0);
    await tester.pumpWidget(_app(AddActivityScreen(inSheet: false, debugStartTime: startAt)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/add_activity');
  });

  testGoldens('add_activity_dark', (tester) async {
    await _setSurfaceSize(tester);
    final startAt = DateTime(2025, 11, 5, 9, 0);
    await tester.pumpWidget(_appDark(AddActivityScreen(inSheet: false, debugStartTime: startAt)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/add_activity_dark');
  });

  testGoldens('activity_detail', (tester) async {
    await _setSurfaceSize(tester);
    final a = ActivityModel(
      activityId: 'A1',
      activityName: 'Breakfast',
      startTime: DateTime(2025, 11, 5, 8, 0),
      endTime: DateTime(2025, 11, 5, 8, 30),
      category: 'Meals',
      source: ActivitySource.manual,
      steps: null,
      screenTimeMinutes: null,
      mealPhotoUrl: null,
      mealCalories: 320,
      mealHealthScore: 72,
    );
    await tester.pumpWidget(_app(ActivityDetailScreen(activity: a, inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/activity_detail');
  });

  testGoldens('activity_detail_dark', (tester) async {
    await _setSurfaceSize(tester);
    final a = ActivityModel(
      activityId: 'A1',
      activityName: 'Breakfast',
      startTime: DateTime(2025, 11, 5, 8, 0),
      endTime: DateTime(2025, 11, 5, 8, 30),
      category: 'Meals',
      source: ActivitySource.manual,
      steps: null,
      screenTimeMinutes: null,
      mealPhotoUrl: null,
      mealCalories: 320,
      mealHealthScore: 72,
    );
    await tester.pumpWidget(_appDark(ActivityDetailScreen(activity: a, inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/activity_detail_dark');
  });

  testGoldens('settings', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const SettingsScreen(inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/settings');
  });

  testGoldens('settings_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const SettingsScreen(inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/settings_dark');
  });

  testGoldens('permissions', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const PermissionsScreen(inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/permissions');
  });

  testGoldens('permissions_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const PermissionsScreen(inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/permissions_dark');
  });

  testGoldens('category_manager', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const CategoryManagerScreen(inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/category_manager');
  });

  testGoldens('category_manager_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const CategoryManagerScreen(inSheet: false)));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/category_manager_dark');
  });

  // Sheet variants (simulated)
  Future<void> _captureSheet(WidgetTester tester, Widget sheet, String name) async {
    await _setSurfaceSize(tester);
    final scrim = Container(color: Colors.black.withOpacity(0.3));
    await tester.pumpWidget(_app(
      Scaffold(
        body: Stack(
          children: [
            const SizedBox.expand(),
            scrim,
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(heightFactor: 0.94, child: sheet),
            ),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/' + name);
  }

  Future<void> _captureSheetDark(WidgetTester tester, Widget sheet, String name) async {
    await _setSurfaceSize(tester);
    final scrim = Container(color: Colors.black.withOpacity(0.6));
    await tester.pumpWidget(_appDark(
      Scaffold(
        body: Stack(
          children: [
            const SizedBox.expand(),
            scrim,
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(heightFactor: 0.94, child: sheet),
            ),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/' + name);
  }

  testGoldens('sheet_add_activity', (tester) async {
    await _captureSheet(tester, AddActivityScreen(inSheet: true, debugStartTime: DateTime(2025, 11, 5, 9, 0)), 'sheet_add_activity');
  });
  testGoldens('sheet_add_activity_dark', (tester) async {
    await _captureSheetDark(tester, AddActivityScreen(inSheet: true, debugStartTime: DateTime(2025, 11, 5, 9, 0)), 'sheet_add_activity_dark');
  });
  testGoldens('sheet_activity_detail', (tester) async {
    final a = ActivityModel(
      activityId: 'A1',
      activityName: 'Breakfast',
      startTime: DateTime(2025, 11, 5, 8, 0),
      endTime: DateTime(2025, 11, 5, 8, 30),
      category: 'Meals',
      source: ActivitySource.manual,
      mealCalories: 320,
      mealHealthScore: 72,
    );
    await _captureSheet(tester, ActivityDetailScreen(activity: a, inSheet: true), 'sheet_activity_detail');
  });
  testGoldens('sheet_activity_detail_dark', (tester) async {
    final a = ActivityModel(
      activityId: 'A1',
      activityName: 'Breakfast',
      startTime: DateTime(2025, 11, 5, 8, 0),
      endTime: DateTime(2025, 11, 5, 8, 30),
      category: 'Meals',
      source: ActivitySource.manual,
      mealCalories: 320,
      mealHealthScore: 72,
    );
    await _captureSheetDark(tester, ActivityDetailScreen(activity: a, inSheet: true), 'sheet_activity_detail_dark');
  });
  testGoldens('sheet_permissions', (tester) async {
    await _captureSheet(tester, const PermissionsScreen(inSheet: true), 'sheet_permissions');
  });
  testGoldens('sheet_permissions_dark', (tester) async {
    await _captureSheetDark(tester, const PermissionsScreen(inSheet: true), 'sheet_permissions_dark');
  });
  testGoldens('sheet_settings', (tester) async {
    await _captureSheet(tester, const SettingsScreen(inSheet: true), 'sheet_settings');
  });
  testGoldens('sheet_settings_dark', (tester) async {
    await _captureSheetDark(tester, const SettingsScreen(inSheet: true), 'sheet_settings_dark');
  });
  testGoldens('sheet_category_manager', (tester) async {
    await _captureSheet(tester, const CategoryManagerScreen(inSheet: true), 'sheet_category_manager');
  });
  testGoldens('sheet_category_manager_dark', (tester) async {
    await _captureSheetDark(tester, const CategoryManagerScreen(inSheet: true), 'sheet_category_manager_dark');
  });
  testGoldens('sheet_quick_actions', (tester) async {
    // There is no Quick Actions sheet now; capture Home as a stand-in.
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_app(const HomeScreen()));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/sheet_quick_actions');
  });
  testGoldens('sheet_quick_actions_dark', (tester) async {
    await _setSurfaceSize(tester);
    await tester.pumpWidget(_appDark(const HomeScreen()));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await screenMatchesGolden(tester, 'docs/screenshots/individual/sheet_quick_actions_dark');
  });
  }, config: GoldenToolkitConfiguration());
}

// ---- Sample data ----
List<ActivityModel> _sampleToday() {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  return [
    ActivityModel(
      activityId: '1',
      activityName: 'Morning Routine',
      startTime: day.add(const Duration(hours: 6, minutes: 0)),
      endTime: day.add(const Duration(hours: 7, minutes: 0)),
      category: 'Hygiene',
      source: ActivitySource.manual,
    ),
    ActivityModel(
      activityId: '1b',
      activityName: 'Meditation',
      startTime: day.add(const Duration(hours: 7, minutes: 0)),
      endTime: day.add(const Duration(hours: 7, minutes: 20)),
      category: 'Personal',
      source: ActivitySource.manual,
    ),
    ActivityModel(
      activityId: '2',
      activityName: 'Commute',
      startTime: day.add(const Duration(hours: 7, minutes: 30)),
      endTime: day.add(const Duration(hours: 8, minutes: 0)),
      category: 'Travel',
      source: ActivitySource.auto,
    ),
    ActivityModel(
      activityId: '3',
      activityName: 'Work Session',
      startTime: day.add(const Duration(hours: 9)),
      endTime: day.add(const Duration(hours: 12)),
      category: 'Work',
      source: ActivitySource.manual,
      steps: 800,
    ),
    ActivityModel(
      activityId: '4',
      activityName: 'Lunch',
      startTime: day.add(const Duration(hours: 12)),
      endTime: day.add(const Duration(hours: 12, minutes: 45)),
      category: 'Meals',
      source: ActivitySource.manual,
      mealCalories: 520,
      mealHealthScore: 68,
    ),
    ActivityModel(
      activityId: '5',
      activityName: 'Focus Deep Work',
      startTime: day.add(const Duration(hours: 13)),
      endTime: day.add(const Duration(hours: 16)),
      category: 'Productivity',
      source: ActivitySource.manual,
      screenTimeMinutes: 95,
    ),
    ActivityModel(
      activityId: '5b',
      activityName: 'Coffee Break',
      startTime: day.add(const Duration(hours: 16)),
      endTime: day.add(const Duration(hours: 16, minutes: 15)),
      category: 'Personal',
      source: ActivitySource.manual,
    ),
    ActivityModel(
      activityId: '6',
      activityName: 'Gym',
      startTime: day.add(const Duration(hours: 18)),
      endTime: day.add(const Duration(hours: 19)),
      category: 'Growth',
      source: ActivitySource.auto,
      steps: 3500,
    ),
    ActivityModel(
      activityId: '6b',
      activityName: 'Dinner',
      startTime: day.add(const Duration(hours: 19, minutes: 30)),
      endTime: day.add(const Duration(hours: 20)),
      category: 'Meals',
      source: ActivitySource.manual,
      mealCalories: 610,
      mealHealthScore: 60,
    ),
    ActivityModel(
      activityId: '7',
      activityName: 'Reading',
      startTime: day.add(const Duration(hours: 21)),
      endTime: day.add(const Duration(hours: 22)),
      category: 'Fun',
      source: ActivitySource.manual,
    ),
  ];
}

List<ActivityModel> _sampleWeek() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final out = <ActivityModel>[];
  for (int i = 0; i < 7; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    out.addAll([
      ActivityModel(
        activityId: 'w${i}p',
        activityName: 'Commute',
        startTime: d.add(const Duration(hours: 8, minutes: 30)),
        endTime: d.add(const Duration(hours: 9)),
        category: 'Travel',
        source: ActivitySource.auto,
      ),
      ActivityModel(
        activityId: 'w${i}a',
        activityName: 'Work',
        startTime: d.add(const Duration(hours: 9)),
        endTime: d.add(const Duration(hours: 12)),
        category: 'Work',
        source: ActivitySource.manual,
        steps: 500 + i * 50,
        screenTimeMinutes: 60 + i * 5,
      ),
      ActivityModel(
        activityId: 'w${i}b',
        activityName: 'Meals',
        startTime: d.add(const Duration(hours: 12)),
        endTime: d.add(const Duration(hours: 12, minutes: 40)),
        category: 'Meals',
        source: ActivitySource.manual,
        mealCalories: 450,
        mealHealthScore: 70,
      ),
      ActivityModel(
        activityId: 'w${i}c',
        activityName: 'Exercise',
        startTime: d.add(const Duration(hours: 18)),
        endTime: d.add(const Duration(hours: 19)),
        category: 'Growth',
        source: ActivitySource.manual,
        steps: 2000 + i * 100,
      ),
      ActivityModel(
        activityId: 'w${i}d',
        activityName: 'Entertainment',
        startTime: d.add(const Duration(hours: 20)),
        endTime: d.add(const Duration(hours: 21)),
        category: 'Fun',
        source: ActivitySource.manual,
        screenTimeMinutes: 45 + i * 3,
      ),
    ]);
  }
  return out;
}
