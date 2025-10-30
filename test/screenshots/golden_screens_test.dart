// Golden screenshots for documentation. Generate images under docs/screenshots.
// Run: flutter test --update-goldens test/screenshots/golden_screens_test.dart

import 'dart:io';
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
import 'package:dghabit/screens/permissions_screen.dart';
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
      // Ensure target folder for individual images exists
      Directory('docs/screenshots/individual').createSync(recursive: true);
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
          ..addScenario(widget: _appShell(const SettingsScreen(inSheet: true), fake), name: 'SettingsSheet')
          ..addScenario(widget: _appShell(const CategoryManagerScreen(inSheet: true), fake), name: 'CategoryManagerSheet')
          ..addScenario(widget: _appShell(const PermissionsScreen(inSheet: true), fake), name: 'PermissionsSheet')
          ..addScenario(widget: _appShell(const PermissionsScreen(), fake), name: 'Permissions')
          ..addScenario(widget: _appShell(const SettingsScreen(), fake), name: 'Settings')
          ..addScenario(widget: _appShell(const CategoryManagerScreen(), fake), name: 'CategoryManager')
          ..addScenario(widget: const _QuickActionsPreview(), name: 'QuickActionsSheet')
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

        // Also capture separate PNGs for each screen as-is (no title overlay)
        Future<void> capture(String fileName, Widget widget) async {
          await tester.pumpWidgetBuilder(widget, surfaceSize: Device.phone.size);
          await screenMatchesGolden(tester, 'individual/' + fileName);
        }

        await capture('home', _appShell(const HomeScreen(), fake));
        await capture('timeline', _appShell(const TimelineScreen(), fake));
        await capture('analytics', _appShell(const AnalyticsScreen(), fake));
        await capture('add_activity', _appShell(const AddActivityScreen(), fake));
        await capture('sheet_add_activity', _appShell(const AddActivityScreen(inSheet: true), fake));
        await capture('settings', _appShell(const SettingsScreen(), fake));
        await capture('sheet_settings', _appShell(const SettingsScreen(inSheet: true), fake));
        await capture('category_manager', _appShell(const CategoryManagerScreen(), fake));
        await capture('sheet_category_manager', _appShell(const CategoryManagerScreen(inSheet: true), fake));
  await capture('sheet_permissions', _appShell(const PermissionsScreen(inSheet: true), fake));
  await capture('permissions', _appShell(const PermissionsScreen(), fake));
        await capture(
          'activity_detail',
          _appShell(
            ActivityDetailScreen(
              activity: ActivityModel(
                activityId: 'detail2',
                activityName: 'Leisure',
                startTime: DateTime.now().subtract(const Duration(hours: 3)),
                endTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
                category: 'Fun',
                source: ActivitySource.manual,
                steps: null,
                screenTimeMinutes: 55,
              ),
            ),
            fake,
          ),
        );
        await capture(
          'sheet_activity_detail',
          _appShell(
            ActivityDetailScreen(
              inSheet: true,
              activity: ActivityModel(
                activityId: 'detail3',
                activityName: 'Walk',
                startTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
                endTime: DateTime.now().subtract(const Duration(minutes: 15)),
                category: 'Health',
                source: ActivitySource.manual,
                steps: 1500,
                screenTimeMinutes: null,
              ),
            ),
            fake,
          ),
        );
        // Test-safe previews (no SVGs, no timers) for Splash and Onboarding
        await capture('splash', _appShell(const _SplashPreview(), fake));
        await capture('onboarding', _appShell(const _OnboardingPreview(), fake));
        await capture('sheet_quick_actions', const _QuickActionsPreview());
      }, config: GoldenToolkitConfiguration(
        // Resolve goldens to the project root docs/ folder regardless of test working dir
        fileNameFactory: (name) => '../../docs/screenshots/' + name + '.png',
      ));
    });
  });
}

class _SplashPreview extends StatelessWidget {
  const _SplashPreview();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final hero = size.shortestSide.clamp(120.0, 220.0);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/brand/icon_1024.png',
                width: hero * 0.8,
                height: hero * 0.8,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text('dgHabit', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Build habits, day by day', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            SizedBox(
              width: hero * 0.35,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: 0.66,
                  backgroundColor: scheme.onSurface.withOpacity(0.06),
                  color: scheme.primary,
                  minHeight: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPreview extends StatelessWidget {
  const _OnboardingPreview();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome'), actions: [TextButton(onPressed: () {}, child: const Text('Skip'))]),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/brand/icon_1024.png', width: 56, height: 56, fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Text('dgHabit', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .2)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outlineVariant.withOpacity(0.25)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timeline, size: 96, color: scheme.primary),
                        const SizedBox(height: 16),
                        Text('Track your day', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('Log activities with smart continuity that fills gaps.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: i==0? scheme.primary: scheme.outlineVariant.withOpacity(0.6), width: 1.6)),
                child: Container(margin: const EdgeInsets.all(2.2), decoration: BoxDecoration(color: i==0? scheme.primary: Colors.transparent, shape: BoxShape.circle)),
              )),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  TextButton(onPressed: () {}, child: const Text('Skip')),
                  const Spacer(),
                  FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.arrow_forward), label: const Text('Next')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsPreview extends StatelessWidget {
  const _QuickActionsPreview();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.timelapse_outlined),
                  title: Text('Record screen time (today)'),
                ),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.flag_circle_outlined),
                  title: Text('Show today steps'),
                ),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.directions_walk),
                  title: Text('Start steps session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
