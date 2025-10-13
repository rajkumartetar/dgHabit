// lib/screens/timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../widgets/activity_card.dart';
import '../providers/app_providers.dart';
import 'activity_detail_screen.dart';
import '../theme/app_decor.dart';
import '../theme/category_colors.dart';

class TimelineDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime d) {
    state = DateTime(d.year, d.month, d.day);
  }
}

final timelineDayProvider = NotifierProvider<TimelineDayNotifier, DateTime>(TimelineDayNotifier.new);
final dayActivitiesProvider = StreamProvider<List<ActivityModel>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  final day = ref.watch(timelineDayProvider);
  final d = DateTime(day.year, day.month, day.day);
  return service.activitiesStream(day: d);
});


class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final asyncActivities = ref.watch(dayActivitiesProvider);

    final decor = Theme.of(context).extension<AppDecor>();
    final day = ref.watch(timelineDayProvider);
    final isToday = DateTime.now().difference(day).inDays == 0 && day.day == DateTime.now().day && day.month == DateTime.now().month && day.year == DateTime.now().year;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Yesterday'),
                selected: !isToday,
                onSelected: (_) {
                  final y = DateTime.now().subtract(const Duration(days: 1));
                  ref.read(timelineDayProvider.notifier).setDate(y);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Today'),
                selected: isToday,
                onSelected: (_) {
                  final t = DateTime.now();
                  ref.read(timelineDayProvider.notifier).setDate(t);
                },
              ),
            ],
          ),
        ),
        FutureBuilder<List<String>>(
          future: _categoriesForDay(ref),
          builder: (context, snap) {
            final cats = snap.data ?? const <String>[];
            if (cats.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: cats.map((c) => _LegendDot(label: c)).toList(),
              ),
            );
          },
        ),
        Expanded(
          child: asyncActivities.when(
      data: (list) => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (c, i) => GestureDetector(
          onTap: () async {
            final changed = await Navigator.of(c).push<bool>(
              MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: list[i])),
            );
            if (changed == true) {
              // No-op; stream will update
            }
          },
          child: Container(
            decoration: decor == null ? null : BoxDecoration(gradient: decor.surfaceGradient, borderRadius: BorderRadius.circular(16)),
            child: ActivityCard(
              activity: list[i],
              onDelete: () => ref.read(firebaseServiceProvider).deleteActivity(list[i].activityId),
            ),
          ),
        ),
  separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemCount: list.length,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

Future<List<String>> _categoriesForDay(WidgetRef ref) async {
  final day = ref.read(timelineDayProvider);
  final service = ref.read(firebaseServiceProvider);
  final list = await service.activitiesStream(day: day).first;
  final set = <String>{};
  for (final a in list) {
    set.add(a.category);
  }
  return set.toList()..sort();
}

class _LegendDot extends StatelessWidget {
  final String label;
  const _LegendDot({required this.label});
  @override
  Widget build(BuildContext context) {
    final color = categoryColor(context, label);
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      label: Text(label),
    );
  }
}
