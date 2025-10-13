// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/activity_model.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fl_chart/fl_chart.dart' as fl;
import '../theme/category_colors.dart';
import '../theme/app_decor.dart';
import 'package:usage_stats/usage_stats.dart' as us;
import '../services/app_info_channel.dart';

final weeklyAnalyticsProvider = StreamProvider<WeeklyAnalytics>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return service.activitiesStreamRange(start: start, end: end).map((list) => WeeklyAnalytics.fromActivities(list));
});

final todayCategoryProvider = StreamProvider<Map<String, Duration>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return service
      .activitiesStreamRange(start: start, end: end)
      .map((acts) {
        final map = <String, Duration>{};
        for (final a in acts) {
          map[a.category] = (map[a.category] ?? Duration.zero) + a.duration;
        }
        return map;
      });
});

class WeeklyAnalytics {
  final Duration totalDuration;
  final Map<String, Duration> byCategory;
  final int totalSteps;
  final double totalScreenMinutes;
  final List<DayTotal> perDay;
  final Map<DateTime, Map<String, Duration>> perDayByCategory;

  WeeklyAnalytics({required this.totalDuration, required this.byCategory, required this.totalSteps, required this.totalScreenMinutes, required this.perDay, required this.perDayByCategory});

  factory WeeklyAnalytics.fromActivities(List<ActivityModel> list) {
    Duration total = Duration.zero;
    final Map<String, Duration> cat = {};
    int steps = 0;
    double screen = 0;
    // Precompute per-day totals for last 7 days
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final Map<DateTime, Duration> perDay = {
      for (int i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i): Duration.zero
    };
    final Map<DateTime, Map<String, Duration>> perDayByCategory = {
      for (int i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i): <String, Duration>{}
    };

    for (final a in list) {
      final d = a.duration;
      total += d;
      cat[a.category] = (cat[a.category] ?? Duration.zero) + d;
      steps += a.steps ?? 0;
      screen += a.screenTimeMinutes ?? 0;
      final key = DateTime(a.startTime.year, a.startTime.month, a.startTime.day);
      perDay[key] = (perDay[key] ?? Duration.zero) + d;
      final map = perDayByCategory[key] ?? <String, Duration>{};
      map[a.category] = (map[a.category] ?? Duration.zero) + d;
      perDayByCategory[key] = map;
    }
    final perDayList = perDay.entries.map((e) => DayTotal(e.key, e.value)).toList()..sort((a, b) => a.day.compareTo(b.day));
    return WeeklyAnalytics(totalDuration: total, byCategory: cat, totalSteps: steps, totalScreenMinutes: screen, perDay: perDayList, perDayByCategory: perDayByCategory);
  }
}

class DayTotal {
  final DateTime day;
  final Duration dur;
  DayTotal(this.day, this.dur);
}

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(weeklyAnalyticsProvider);
    final decor = Theme.of(context).extension<AppDecor>();
    return asyncData.when(
      data: (data) {
        final totalH = data.totalDuration.inHours;
        final totalM = data.totalDuration.inMinutes % 60;
        final todayCats = ref.watch(todayCategoryProvider);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Weekly Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              child: Container(
                decoration: decor == null ? null : BoxDecoration(gradient: decor.surfaceGradient),
                child: ListTile(
                leading: const Icon(Icons.timer),
                title: Text('Total time: ${totalH}h ${totalM.toString().padLeft(2, '0')}m'),
                subtitle: Text('Steps: ${data.totalSteps} • Screen: ${data.totalScreenMinutes.toStringAsFixed(1)} min'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  height: 220,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(),
                    primaryYAxis: NumericAxis(title: AxisTitle(text: 'Hours')),
                    series: <CartesianSeries<DayTotal, String>>[
                      ColumnSeries<DayTotal, String>(
                        dataSource: data.perDay,
                        xValueMapper: (d, _) => _shortDay(d.day),
                        yValueMapper: (d, _) => d.dur.inMinutes / 60.0,
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Weekly by category', style: Theme.of(context).textTheme.titleMedium),
            Builder(builder: (context) {
              final days = data.perDay.map((e) => e.day).toList();
              final categories = data.byCategory.keys.toList();
              final totalWeekMin = data.totalDuration.inMinutes;
              if (categories.isEmpty || totalWeekMin < 30) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Not enough data to show weekly charts'),
                    subtitle: const Text('Log more activities to unlock weekly category insights.'),
                  ),
                );
              }
              final series = categories.map((catName) {
                return StackedColumnSeries<DateValue, String>(
                  dataSource: days.map((d) {
                    final mins = (data.perDayByCategory[d]?[catName] ?? Duration.zero).inMinutes.toDouble();
                    return DateValue(d, mins / 60.0);
                  }).toList(),
                  xValueMapper: (dv, _) => _shortDay(dv.date),
                  yValueMapper: (dv, _) => dv.value,
                  color: categoryColor(context, catName),
                  name: catName,
                );
              }).toList();
              return SizedBox(
                height: 240,
                child: SfCartesianChart(
                  legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                  primaryXAxis: CategoryAxis(),
                  primaryYAxis: NumericAxis(title: AxisTitle(text: 'Hours')),
                  series: series,
                ),
              );
            }),
            const SizedBox(height: 8),
            Text('Weekly category share', style: Theme.of(context).textTheme.titleMedium),
            Builder(builder: (context) {
              final entries = data.byCategory.entries.where((e) => e.value > Duration.zero).toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final totalMin = entries.fold<double>(0, (s, e) => s + e.value.inMinutes.toDouble());
              if (entries.isEmpty || totalMin < 30) {
                return const ListTile(title: Text('Not enough data to show weekly category share'));
              }
              return SizedBox(
                height: 220,
                child: fl.PieChart(
                  fl.PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: entries
                        .map(
                          (e) => fl.PieChartSectionData(
                            color: categoryColor(context, e.key),
                            value: e.value.inMinutes.toDouble(),
                            title: _pct(e.value.inMinutes.toDouble(), totalMin),
                            radius: 70,
                          ),
                        )
                        .toList(),
                    pieTouchData: fl.PieTouchData(
                      touchCallback: (fl.FlTouchEvent event, fl.PieTouchResponse? response) {
                        final touched = response?.touchedSection;
                        if (touched == null) return;
                        final idx = touched.touchedSectionIndex;
                        if (idx < 0 || idx >= entries.length) return;
                        final e = entries[idx];
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${e.key}: ${_pct(e.value.inMinutes.toDouble(), totalMin)}')),
                        );
                      },
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text('Today by category', style: Theme.of(context).textTheme.titleMedium),
            todayCats.when(
              data: (catMap) {
                final entries = catMap.entries.where((e) => e.value > Duration.zero).toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final totalMin = entries.fold<double>(0, (s, e) => s + e.value.inMinutes.toDouble());
                if (entries.isEmpty || totalMin <= 0) {
                  return const ListTile(title: Text('No data for today'));
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: fl.PieChart(
                        fl.PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: entries
                              .map(
                                (e) => fl.PieChartSectionData(
                                  color: categoryColor(context, e.key),
                                  value: e.value.inMinutes.toDouble(),
                                  title: _pct(e.value.inMinutes.toDouble(), totalMin),
                                  radius: 70,
                                ),
                              )
                              .toList(),
                          pieTouchData: fl.PieTouchData(
                            touchCallback: (fl.FlTouchEvent event, fl.PieTouchResponse? response) {
                              final touched = response?.touchedSection;
                              if (touched == null) return;
                              final idx = touched.touchedSectionIndex;
                              if (idx < 0 || idx >= entries.length) return;
                              final e = entries[idx];
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${e.key}: ${_pct(e.value.inMinutes.toDouble(), totalMin)}')),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    ...entries.map((e) => ListTile(
                          leading: const Icon(Icons.label_outline),
                          title: Text(e.key),
                          trailing: Text('${e.value.inHours}h ${(e.value.inMinutes % 60).toString().padLeft(2, '0')}m'),
                        )),
                  ],
                );
              },
              loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              error: (e, st) => ListTile(title: Text('Error: $e')),
            ),
            const SizedBox(height: 8),
            Text('Top apps screen time (today)', style: Theme.of(context).textTheme.titleMedium),
            Consumer(builder: (context, ref, _) {
              if (!Platform.isAndroid) {
                return const ListTile(title: Text('App usage not available on this platform'));
              }
              final now = DateTime.now();
              final start = DateTime(now.year, now.month, now.day);
              final sensor = ref.read(sensorServiceProvider);
              return FutureBuilder<Map<String, Duration>?>(
                future: sensor.getPerAppScreenTimeMap(start, now),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
                  }
                  final map = snap.data;
                  if (map == null || map.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(title: Text('No app usage data (grant Usage Access)')),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.settings),
                            label: const Text('Open Usage Access settings'),
                            onPressed: () => us.UsageStats.grantUsagePermission(),
                          ),
                        ),
                      ],
                    );
                  }
                  final top = map.entries.where((e) => !_isThisApp(e.key)).toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final top5 = top.take(5).toList();
                  final channel = AppInfoChannel();
                  return FutureBuilder<Map<String, AppInfoItem>>(
                    future: channel.fetchMany(top5.map((e) => e.key)),
                    builder: (context, infoSnap) {
                      final info = infoSnap.data;
                      return Card(
                        child: Column(
                          children: top5.map((e) {
                            final item = info?[e.key];
                            final leading = (item?.icon != null)
                                ? CircleAvatar(backgroundImage: MemoryImage(item!.icon!))
                                : const Icon(Icons.apps);
                            var title = item?.name ?? _friendlyAppName(e.key);
                            if (title == e.key) title = 'Unknown app';
                            return ListTile(
                              leading: leading,
                              title: Text(title),
                              trailing: Text(_fmtHm(e.value)),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

String _shortDay(DateTime d) {
  // e.g., Mon, Tue; for locale simplicity use fixed English abbreviations
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = d.weekday; // 1..7 Mon..Sun
  return names[(wd - 1) % 7];
}

String _pct(double value, double total) {
  if (total <= 0) return '';
  final p = (value / total) * 100;
  if (p < 1) return '<1%';
  return '${p.toStringAsFixed(0)}%';
}

class DateValue {
  final DateTime date;
  final double value;
  DateValue(this.date, this.value);
}

String _fmtHm(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

// Best-effort friendly names without device_apps
String _friendlyAppName(String packageName) {
  const map = {
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.facebook.katana': 'Facebook',
    'com.google.android.youtube': 'YouTube',
    'com.google.android.apps.photos': 'Google Photos',
    'com.google.android.apps.messaging': 'Messages',
    'com.google.android.gm': 'Gmail',
    'com.google.android.apps.maps': 'Google Maps',
    'com.android.chrome': 'Chrome',
    'org.telegram.messenger': 'Telegram',
    'com.snapchat.android': 'Snapchat',
    'com.twitter.android': 'Twitter',
    'com.x.android': 'X',
    'com.netflix.mediaclient': 'Netflix',
    'in.mohalla.video': 'Moj',
    'com.sharechat.android': 'ShareChat',
  };
  return map[packageName] ?? packageName;
}

bool _isThisApp(String packageName) {
  // Filter out this app's own package so it doesn't appear in the top apps list.
  // Update this if the applicationId differs.
  const candidates = <String>{
    'com.example.dghabit', // default Flutter appId often used during dev
    'com.example.dghabit.debug',
  };
  return candidates.contains(packageName);
}
