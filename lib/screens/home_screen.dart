
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timeline_screen.dart';
import 'analytics_screen.dart';
import 'add_activity_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'permissions_screen.dart';
import 'settings_screen.dart';
import '../models/activity_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // Steps session state
  int? _stepsBaseline;
  int? _stepsLatest;
  DateTime? _stepsSessionStart;
  static const List<Widget> _widgetOptions = <Widget>[
    TimelineScreen(),
    AnalyticsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dgHabit'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: SettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Permissions',
            icon: const Icon(Icons.privacy_tip_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: PermissionsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Auth status',
            icon: const Icon(Icons.verified_user),
            onPressed: () {
              final u = FirebaseAuth.instance.currentUser;
              final msg = u == null ? 'Not signed in' : 'Signed in as ${u.email ?? u.uid}';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Quick Actions mini-FAB
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.small(
              heroTag: 'quick_actions',
              tooltip: 'Quick Actions',
              onPressed: _showQuickActionsSheet,
              child: const Icon(Icons.bolt_outlined),
            ),
          ),
          // Primary Add Activity FAB
          FloatingActionButton(
            heroTag: 'add_activity',
            onPressed: () async {
              final added = await showModalBottomSheet<bool>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: AddActivityScreen(inSheet: true)),
              );
              if (added == true && mounted) {
                setState(() {
                  _selectedIndex = 0; // switch to Timeline
                });
              }
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      // Footer actions moved into Quick Actions sheet; no persistentFooterButtons.
    );
  }

  void _showQuickActionsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final running = _stepsSessionStart != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                Consumer(builder: (context, ref, _) {
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.timelapse_outlined),
                    title: const Text('Record screen time (today)'),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      Navigator.of(ctx).pop();
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final sensor = ref.read(sensorServiceProvider);
                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month, now.day);
                      final end = now;
                      final dur = await sensor.getThisAppScreenTime(start, end) ?? await sensor.getScreenTime(start, end);
                      if (dur == null) {
                        messenger?.showSnackBar(const SnackBar(content: Text('Screen time unavailable. Please grant Usage Access in Permissions.')));
                        return;
                      }
                      final minutes = dur.inMinutes.toDouble();
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      await ref.read(firebaseServiceProvider).insertActivityContinuous(
                            ActivityModel(
                              activityId: id,
                              activityName: 'Screen time',
                              startTime: start,
                              endTime: end,
                              category: 'Device',
                              source: ActivitySource.auto,
                              screenTimeMinutes: minutes,
                            ),
                          );
                      messenger?.showSnackBar(SnackBar(content: Text('Recorded ${minutes.toStringAsFixed(1)} min screen time')));
                    },
                  );
                }),
                Consumer(builder: (context, ref, _) {
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.flag_circle_outlined),
                    title: const Text('Show today steps'),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      Navigator.of(ctx).pop();
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final sensor = ref.read(sensorServiceProvider);
                      final steps = await sensor.getTodaySteps();
                      if (steps == null) {
                        messenger?.showSnackBar(const SnackBar(content: Text('Steps unavailable. Please grant Physical Activity permission.')));
                        return;
                      }
                      messenger?.showSnackBar(SnackBar(content: Text('Today steps so far: $steps')));
                    },
                  );
                }),
                Consumer(builder: (context, ref, _) {
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(running ? Icons.stop_circle_outlined : Icons.directions_walk),
                    title: Text(running ? 'Stop & save steps' : 'Start steps session'),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      Navigator.of(ctx).pop();
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final sensor = ref.read(sensorServiceProvider);
                      if (!running) {
                        _stepsBaseline = null;
                        _stepsLatest = null;
                        setState(() {
                          _stepsSessionStart = DateTime.now();
                        });
                        sensor.startStepStream(onData: (sc) {
                          final steps = sc.steps;
                          setState(() {
                            _stepsLatest = steps;
                            _stepsBaseline ??= steps;
                          });
                        }, onError: (e) {
                          messenger?.showSnackBar(SnackBar(content: Text('Steps error: $e')));
                        });
                        messenger?.showSnackBar(const SnackBar(content: Text('Steps session started')));
                      } else {
                        sensor.stopStepStream();
                        final start = _stepsSessionStart!;
                        final end = DateTime.now();
                        final delta = (_stepsLatest ?? 0) - (_stepsBaseline ?? 0);
                        if (delta > 0) {
                          final id = DateTime.now().millisecondsSinceEpoch.toString();
                          await ref.read(firebaseServiceProvider).insertActivityContinuous(
                                ActivityModel(
                                  activityId: id,
                                  activityName: 'Walking',
                                  startTime: start,
                                  endTime: end,
                                  category: 'Health',
                                  source: ActivitySource.auto,
                                  steps: delta,
                                ),
                              );
                          messenger?.showSnackBar(SnackBar(content: Text('Recorded $delta steps')));
                        } else {
                          messenger?.showSnackBar(const SnackBar(content: Text('No steps recorded')));
                        }
                        setState(() {
                          _stepsSessionStart = null;
                          _stepsBaseline = null;
                          _stepsLatest = null;
                        });
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
