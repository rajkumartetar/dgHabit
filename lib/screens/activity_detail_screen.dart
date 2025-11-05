import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../services/firebase_service.dart';
import '../widgets/sheet_header.dart';
import '../widgets/meal_editor.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  final ActivityModel activity;
  final bool inSheet;
  const ActivityDetailScreen({super.key, required this.activity, this.inSheet = false});

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  late TextEditingController _nameCtrl;
  final TextEditingController _customCatCtrl = TextEditingController();
  late String _category;
  late DateTime _start;
  late DateTime _end;
  static const List<String> _defaultCategories = ['Personal', 'Hygiene', 'Travel', 'Work', 'Fun', 'Productivity', 'Growth'];
  // Include 'Meals' in defaults
  static const List<String> _mealAwareDefaults = ['Personal', 'Hygiene', 'Travel', 'Work', 'Fun', 'Productivity', 'Growth', 'Meals'];
  List<String> _categories = [];
  final TextEditingController _caloriesCtrl = TextEditingController();
  final TextEditingController _healthScoreCtrl = TextEditingController();
  Uint8List? _mealNewBytes;
  bool _clearMealPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.activity.activityName);
    _category = widget.activity.category;
    _start = widget.activity.startTime;
    _end = widget.activity.endTime;
    // Ensure the dropdown items initially contain the current category
    final baseSet = {
      ..._defaultCategories,
      // Include current category (e.g., 'Meals') to satisfy Dropdown invariant on first build
      if (widget.activity.category.isNotEmpty) widget.activity.category,
    };
    final base = baseSet.toList()..sort();
    _categories = [...base, 'Others'];
    if (widget.activity.mealCalories != null) {
      _caloriesCtrl.text = widget.activity.mealCalories!.toStringAsFixed(0);
    }
    if (widget.activity.mealHealthScore != null) {
      _healthScoreCtrl.text = widget.activity.mealHealthScore!.toStringAsFixed(0);
    }
    // Load user's custom categories and merge with defaults; ensure current value exists
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final customs = await ref.read(firebaseServiceProvider).getUserCategories();
      if (!mounted) return;
      final mergedSet = {
        ..._mealAwareDefaults,
        ...customs.where((c) => c.trim().isNotEmpty),
      };
      // Ensure current category is present to satisfy DropdownButton invariant
      mergedSet.add(_category);
      final merged = mergedSet.toList()..sort();
      setState(() {
        _categories = [...merged, 'Others'];
      });
    });
  }

  Future<void> _pickDateTime(bool isStart) async {
    final init = isStart ? _start : _end;
    final ctx = context;
  // ignore: use_build_context_synchronously
  final today = DateTime.now();
  final onlyDay = DateTime(today.year, today.month, today.day);
  final date = await showDatePicker(context: ctx, initialDate: init, firstDate: onlyDay, lastDate: onlyDay);
    if (!mounted || date == null) return;
  // ignore: use_build_context_synchronously
  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(init));
    if (!mounted || time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final clamped = dt.isAfter(endOfDay) ? endOfDay : dt;
    setState(() {
      if (isStart) {
        _start = clamped;
      } else {
        _end = clamped;
      }
    });
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_end.isAfter(_start)) {
      messenger.showSnackBar(const SnackBar(content: Text('End time must be after start time')));
      return;
    }
    // Resolve final category (handle custom when Others selected)
    String finalCategory = _category;
    if (_category == 'Others') {
      final custom = _customCatCtrl.text.trim();
      if (custom.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Please enter a custom category')));
        return;
      }
      finalCategory = custom;
      await ref.read(firebaseServiceProvider).addUserCategory(finalCategory);
    }
    String? photoUrl = widget.activity.mealPhotoUrl;
    double? calories = _caloriesCtrl.text.trim().isNotEmpty ? double.tryParse(_caloriesCtrl.text.trim()) : widget.activity.mealCalories;
    double? score = _healthScoreCtrl.text.trim().isNotEmpty ? double.tryParse(_healthScoreCtrl.text.trim()) : widget.activity.mealHealthScore;
    // Upload or clear meal image if in Meals mode
    if (_category == 'Meals' || widget.activity.mealPhotoUrl != null) {
      final uid = ref.read(firebaseServiceProvider).uid;
      final refSt = FirebaseStorage.instance.ref().child('users/$uid/meals/${widget.activity.activityId}.jpg');
      try {
        if (_clearMealPhoto) {
          // Clear reference (best-effort delete)
          photoUrl = null;
          await refSt.delete().catchError((_){});
        } else if (_mealNewBytes != null) {
          await refSt.putData(_mealNewBytes!);
          photoUrl = await refSt.getDownloadURL();
        }
      } catch (_) {}
      // Simple heuristic if score missing but calories provided
      if (score == null && calories != null) {
        score = (100 - (calories / 10)).clamp(0, 100).toDouble();
      }
    }

    final updated = ActivityModel(
      activityId: widget.activity.activityId,
      activityName: _nameCtrl.text.trim(),
      startTime: _start,
      endTime: _end,
      category: finalCategory,
      source: widget.activity.source,
      steps: widget.activity.steps,
      screenTimeMinutes: widget.activity.screenTimeMinutes,
      mealPhotoUrl: photoUrl,
      mealCalories: calories,
      mealHealthScore: score,
    );
    // Use upsert for direct update; optionally, for start-time changes, we can re-run the continuous logic by reinserting.
    // For MVP, maintain continuity: delete and reinsert with continuous adjustment.
    final service = ref.read(firebaseServiceProvider);
    // When editing, we will delete and re-insert with continuity and choices
    await service.deleteActivity(widget.activity.activityId);
    final info = await service.detectOverlaps(updated);
    if (info.prevOverlap || info.nextOverlap) {
      final res = await _showContinuityDialog(info);
      if (res == null) return;
      await service.insertActivityWithStrategies(
        updated,
        moveNewStartIfPrev: res.moveNewStartIfPrev,
        moveNextStartIfNext: res.moveNextStartIfNext,
      );
    } else {
      await service.insertActivityContinuous(updated);
    }
    nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    return Scaffold(
      appBar: widget.inSheet ? null : AppBar(
        title: const Text('Activity Details'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final nav = Navigator.of(context);
              await ref.read(firebaseServiceProvider).deleteActivity(a.activityId);
              nav.pop(true);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.inSheet)
            SheetHeader(
              title: 'Activity Details',
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await ref.read(firebaseServiceProvider).deleteActivity(a.activityId);
                    nav.pop(true);
                  },
                ),
                IconButton(icon: const Icon(Icons.save), tooltip: 'Save', onPressed: _save),
              ],
              onClose: () => Navigator.of(context).maybePop(),
            ),
          if (widget.inSheet) const SizedBox(height: 8),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _category,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          if (_category == 'Others') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customCatCtrl,
              decoration: const InputDecoration(
                labelText: 'Custom category',
                hintText: 'Enter a category name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Start'),
            subtitle: Text(_start.toString()),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () => _pickDateTime(true),
          ),
          ListTile(
            title: const Text('End'),
            subtitle: Text(_end.toString()),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () => _pickDateTime(false),
          ),
          const SizedBox(height: 12),
          if (a.steps != null) Text('Steps: ${a.steps}'),
          if (a.screenTimeMinutes != null) Text('Screen time: ${a.screenTimeMinutes!.toStringAsFixed(1)} min'),
          if ((_category == 'Meals') || a.mealPhotoUrl != null || a.mealCalories != null || a.mealHealthScore != null) ...[
            const SizedBox(height: 12),
            MealEditor(
              existingUrl: a.mealPhotoUrl,
              initialBytes: _mealNewBytes,
              onBytesChanged: (bytes) => _mealNewBytes = bytes,
              onRemoveChanged: (clear) => _clearMealPhoto = clear,
              caloriesCtrl: _caloriesCtrl,
              healthCtrl: _healthScoreCtrl,
            ),
          ],
        ],
      ),
    );
  }

  Future<_ContinuityChoice?> _showContinuityDialog(OverlapInfo info) async {
    bool moveNewStartIfPrev = false;
    bool moveNextStartIfNext = false;
    final ctx = context;
    String fmt(DateTime? d) => d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return showDialog<_ContinuityChoice>(
      context: ctx,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Adjust continuity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (info.prevOverlap)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Previous overlap (prev ends ${fmt(info.prevEnd)})'),
                    RadioListTile<bool>(
                      title: const Text('Trim previous to new start'),
                      value: false,
                      groupValue: moveNewStartIfPrev,
                      onChanged: (v) => setState(() => moveNewStartIfPrev = v ?? false),
                    ),
                    RadioListTile<bool>(
                      title: Text('Move new start to previous end (${fmt(info.prevEnd)})'),
                      value: true,
                      groupValue: moveNewStartIfPrev,
                      onChanged: (v) => setState(() => moveNewStartIfPrev = v ?? false),
                    ),
                  ],
                ),
              if (info.nextOverlap)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Next overlap (next starts ${fmt(info.nextStart)})'),
                    RadioListTile<bool>(
                      title: const Text('Trim new end to next start'),
                      value: false,
                      groupValue: moveNextStartIfNext,
                      onChanged: (v) => setState(() => moveNextStartIfNext = v ?? false),
                    ),
                    RadioListTile<bool>(
                      title: const Text('Move next start to new end'),
                      value: true,
                      groupValue: moveNextStartIfNext,
                      onChanged: (v) => setState(() => moveNextStartIfNext = v ?? false),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _ContinuityChoice(moveNewStartIfPrev, moveNextStartIfNext)),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _customCatCtrl.dispose();
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _healthScoreCtrl.dispose();
    super.dispose();
  }
}

class _ContinuityChoice {
  final bool moveNewStartIfPrev;
  final bool moveNextStartIfNext;
  _ContinuityChoice(this.moveNewStartIfPrev, this.moveNextStartIfNext);
}

 
