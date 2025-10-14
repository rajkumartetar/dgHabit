// Golden screenshots for documentation. Generate images under docs/screenshots.
// Run: flutter test --update-goldens test/screenshots/golden_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dghabit/services/firebase_service.dart';
import 'package:dghabit/screens/home_screen.dart';
import 'package:dghabit/screens/analytics_screen.dart';
import 'package:dghabit/screens/timeline_screen.dart';
import 'package:dghabit/screens/add_activity_screen.dart';
import 'package:dghabit/screens/activity_detail_screen.dart';
import 'package:dghabit/screens/settings_screen.dart';
import 'package:dghabit/screens/category_manager_screen.dart';
import 'package:dghabit/models/activity_model.dart';
import 'package:dghabit/providers/app_providers.dart';

class _FakeFirebaseService implements FirebaseService {
  final List<ActivityModel> _seed;
  final List<String> _cats = ['Personal','Hygiene','Travel','Work','Fun','Productivity','Growth','Device'];
  _FakeFirebaseService(this._seed);

  @override
  String get uid => 'mock-user';

  @override
  Stream<List<ActivityModel>> activitiesStream({DateTime? day}) async* {
    final d = DateTime(day?.year ?? DateTime.now().year, day?.month ?? DateTime.now().month, day?.day ?? DateTime.now().day);
    yield _seed.where((a) => a.startTime.year == d.year && a.startTime.month == d.month && a.startTime.day == d.day).toList();
  }

  @override
  Stream<List<ActivityModel>> activitiesStreamRange({required DateTime start, required DateTime end}) async* {
    yield _seed.where((a) => !a.startTime.isBefore(start) && !a.startTime.isAfter(end)).toList();
  }

  @override
  Future<List<String>> getUserCategories() async => List.of(_cats);

  // Below are no-ops or simple in-memory variants sufficient for rendering.
  @override
  Future<void> upsertActivity(ActivityModel activity) async {}

  @override
  Future<String> addActivity(ActivityModel activity) async => 'fake-${activity.activityId}';

  @override
  Future<void> insertActivityContinuous(ActivityModel newAct) async {}

  @override
  Future<OverlapInfo> detectOverlaps(ActivityModel act) async =>
      OverlapInfo(prevOverlap: false, nextOverlap: false);

  @override
  Future<void> insertActivityWithStrategies(ActivityModel act, {required bool moveNewStartIfPrev, required bool moveNextStartIfNext}) async {}

  @override
  Future<void> updateActivityContinuous(ActivityModel updated) async {}

  @override
  Future<void> deleteActivity(String activityId) async {}

  @override
  Future<DateTime> lastEndOfToday() async => DateTime.now();

  @override
  Future<void> appendActivityToToday(ActivityModel base) async {}

  @override
  Future<String> connectivityCheck() async => 'OK';

  @override
  Future<void> addUserCategory(String name) async { if(name.trim().isNotEmpty) _cats.add(name.trim()); }

  @override
  Future<void> deleteUserCategory(String name) async { _cats.remove(name.trim()); }

  @override
  Future<void> renameUserCategory({required String from, required String to}) async {
    final f = from.trim();
    final t = to.trim();
    final idx = _cats.indexOf(f);
    if (idx >= 0) _cats[idx] = t;
  }

  @override
  Future<int> countActivitiesUsingCategory(String category) async =>
      _seed.where((a) => a.category == category).length;

  @override
  Future<void> reassignCategory({required String from, required String to}) async {
    for (var i = 0; i < _seed.length; i++) {
      if (_seed[i].category == from) {
        final a = _seed[i];
        _seed[i] = ActivityModel(
          activityId: a.activityId,
          activityName: a.activityName,
          startTime: a.startTime,
          endTime: a.endTime,
          category: to,
          source: a.source,
          steps: a.steps,
          screenTimeMinutes: a.screenTimeMinutes,
        );
      }
    }
  }
}

List<ActivityModel> _generateWeekSeed() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final out = <ActivityModel>[];
  int id = 0;
  final cats = ['Work', 'Health', 'Personal', 'Fun'];
  for (int i = 0; i < 7; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    out.addAll(List.generate(3, (j) {
      final st = DateTime(day.year, day.month, day.day, 9 + j * 3);
      final en = st.add(const Duration(hours: 2));
      return ActivityModel(
        activityId: 'w${id++}',
        activityName: j == 0 ? 'Focus Block' : (j == 1 ? 'Walk' : 'Leisure'),
        startTime: st,
        endTime: en,
        category: cats[(i + j) % cats.length],
        source: ActivitySource.manual,
        steps: j == 1 ? 1200 + i * 50 : null,
        screenTimeMinutes: j == 2 ? 45 + i * 3 : null,
      );
    }));
  }
  return out;
}

Widget _appShell(Widget home, _FakeFirebaseService fake) {
  return ProviderScope(
    overrides: [firebaseServiceProvider.overrideWithValue(fake)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: home,
      routes: {
        '/auth': (_) => const Scaffold(body: Center(child: Text('Auth Placeholder'))),
      },
    ),
  );
}

void main() {
  group('Golden screenshots', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      GoogleFonts.config.allowRuntimeFetching = false;
      await loadAppFonts();
    });

    testGoldens('Capture key screens', (tester) async {
      final fake = _FakeFirebaseService(_generateWeekSeed());
      await GoldenToolkit.runWithConfiguration(() async {
        final builder = DeviceBuilder()
          ..overrideDevicesForAllScenarios(devices: const [Device.phone])
          ..addScenario(widget: _appShell(const HomeScreen(), fake), name: 'Home')
          ..addScenario(widget: _appShell(const TimelineScreen(), fake), name: 'Timeline')
          ..addScenario(widget: _appShell(const AnalyticsScreen(), fake), name: 'Analytics')
          ..addScenario(widget: _appShell(const AddActivityScreen(), fake), name: 'AddActivity')
          ..addScenario(widget: _appShell(const SettingsScreen(), fake), name: 'Settings')
          ..addScenario(widget: _appShell(const CategoryManagerScreen(), fake), name: 'CategoryManager')
          ..addScenario(widget: _appShell(ActivityDetailScreen(
            activity: ActivityModel(
              activityId: 'detail1',
              activityName: 'Focus Block',
              startTime: DateTime.now().subtract(const Duration(hours: 2)),
              endTime: DateTime.now().subtract(const Duration(hours: 1)),
              category: 'Work',
              source: ActivitySource.manual,
              steps: null,
              screenTimeMinutes: 30,
            ),
          ), fake), name: 'ActivityDetail');

        await tester.pumpDeviceBuilder(builder);
        await screenMatchesGolden(tester, 'all_screens');
      }, config: GoldenToolkitConfiguration(
        fileNameFactory: (name) => 'docs/screenshots/' + name + '.png',
      ));
    });
  });
}
