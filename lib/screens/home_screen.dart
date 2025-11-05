
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timeline_screen.dart';
import 'analytics_screen.dart';
import 'add_activity_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'permissions_screen.dart';
import 'settings_screen.dart';
// import '../models/activity_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  // Steps session state
  // Steps quick session removed; keep fields for potential future use commented out.
  // int? _stepsBaseline;
  // int? _stepsLatest;
  // DateTime? _stepsSessionStart;
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
                builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: SettingsScreen(inSheet: true)),
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
                builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: PermissionsScreen(inSheet: true)),
              );
            },
          ),
          // Hide developer-only auth status button in production.
          IconButton(
            tooltip: 'Sign out',
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
          // Physical Activity mini-FAB: show today's steps directly
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.small(
              heroTag: 'show_steps',
              tooltip: "Show today's steps",
              onPressed: () async {
                final sensor = ref.read(sensorServiceProvider);
                final steps = await sensor.getTodaySteps();
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (steps == null) {
                  messenger?.showSnackBar(const SnackBar(content: Text('Steps unavailable. Please grant Physical Activity permission.')));
                } else {
                  messenger?.showSnackBar(SnackBar(content: Text("Today's steps so far: $steps")));
                }
              },
              child: const Icon(Icons.directions_run),
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
      // Footer actions removed.
    );
  }
}
