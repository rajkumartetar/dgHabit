// lib/widgets/activity_card.dart
import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../theme/category_colors.dart';

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ActivityCard({super.key, required this.activity, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final duration = activity.duration;
    return Card(
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: categoryColor(context, activity.category),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(activity.activityName),
        subtitle: Text(
          '${activity.category} • ${_fmt(activity.startTime)} - ${_fmt(activity.endTime)} (${_fmtDur(duration)})'
          '${activity.steps != null ? ' • ${activity.steps} steps' : ''}'
          '${activity.screenTimeMinutes != null ? ' • ${activity.screenTimeMinutes!.toStringAsFixed(1)} min screen' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            if (onDelete != null)
              IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _fmtDur(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
}
