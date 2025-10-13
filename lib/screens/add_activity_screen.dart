// lib/screens/add_activity_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../providers/app_providers.dart';
import '../services/firebase_service.dart';
import '../theme/app_decor.dart';

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key});

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController();
  String _category = 'Personal';
  DateTime _start = DateTime.now();
  DateTime? _end;
  ActivitySource _source = ActivitySource.manual;
  static const List<String> _defaultCategories = [
    'Personal', 'Hygiene', 'Travel', 'Work', 'Fun', 'Productivity', 'Growth'
  ];
  List<String> _categories = [..._defaultCategories, 'Others'];

  @override
  void initState() {
    super.initState();
    // Default start time is current time
    // Load user's custom categories and merge
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final customs = await ref.read(firebaseServiceProvider).getUserCategories();
      if (!mounted) return;
      final merged = <String>{..._defaultCategories, ...customs.where((c) => c.trim().isNotEmpty)}.toList()..sort();
      setState(() {
        _categories = [...merged, 'Others'];
      });
    });
  }

  Future<void> _pickTime(bool isStart) async {
  final init = isStart ? _start : (_end ?? _start);
  final ctx = context; // capture context
  // ignore: use_build_context_synchronously
  final today = DateTime.now();
  final onlyDay = DateTime(today.year, today.month, today.day);
  final date = await showDatePicker(
      context: ctx,
      initialDate: DateTime(init.year, init.month, init.day),
      firstDate: onlyDay,
      lastDate: onlyDay);
    if (!mounted || date == null) return;
  // ignore: use_build_context_synchronously
  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(init));
    if (!mounted || time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    // Ensure within today
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
    if (!_formKey.currentState!.validate()) return;
    if (_end != null && !_end!.isAfter(_start)) {
      messenger.showSnackBar(const SnackBar(content: Text('End time must be after start time')));
      return;
    }
    // Determine final category (handle custom when Others selected)
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
  // If end not specified, default to now (clamped to today). If you want to append
  // to the previous activity's end, use the Quick 'Start now' button below.
    final now = DateTime.now();
    final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final effectiveEnd = _end ?? (now.isAfter(_start) ? now : _start.add(const Duration(minutes: 30)));
    final finalEnd = effectiveEnd.isAfter(endToday) ? endToday : effectiveEnd;
  // Simple unique id based on timestamp; Firestore doc id could also be generated
  final id = DateTime.now().millisecondsSinceEpoch.toString();
    final activity = ActivityModel(
      activityId: id,
      activityName: _nameCtrl.text.trim(),
      startTime: _start,
      endTime: finalEnd,
      category: finalCategory,
      source: _source,
    );
    final service = ref.read(firebaseServiceProvider);
    if (_end == null) {
      await service.appendActivityToToday(activity);
    } else {
      // Check overlaps and let user decide strategies if needed
      final info = await service.detectOverlaps(activity);
      if (info.prevOverlap || info.nextOverlap) {
        final res = await _showContinuityDialog(info);
        if (res == null) return; // cancelled
        await service.insertActivityWithStrategies(
          activity,
          moveNewStartIfPrev: res.moveNewStartIfPrev,
          moveNextStartIfNext: res.moveNextStartIfNext,
        );
      } else {
        await service.insertActivityContinuous(activity);
      }
    }
  nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final decor = Theme.of(context).extension<AppDecor>();
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: decor == null ? null : Container(decoration: BoxDecoration(gradient: decor.headerGradient)),
        title: const Text('Add Activity'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Activity name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _categories.map((c) => ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              )).toList(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            if (_category == 'Others') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _customCatCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom category',
                  hintText: 'Enter a category name',
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Start time'),
              subtitle: Text(_start.toString()),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () => _pickTime(true),
            ),
            SwitchListTile.adaptive(
              title: const Text('Specify end time'),
              value: _end != null,
              onChanged: (v) {
                setState(() {
                  _end = v
                      ? DateTime.now()
                      : null;
                });
              },
            ),
            if (_end != null)
              ListTile(
              title: const Text('End time'),
                subtitle: Text(_end!.toString()),
              trailing: const Icon(Icons.edit_calendar),
                onTap: () => _pickTime(false),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ActivitySource>(
              value: _source,
              decoration: const InputDecoration(labelText: 'Source'),
              items: const [
                DropdownMenuItem(value: ActivitySource.manual, child: Text('Manual')),
                DropdownMenuItem(value: ActivitySource.auto, child: Text('Auto')),
              ],
              onChanged: (v) => setState(() => _source = v ?? ActivitySource.manual),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      // Quick append: no end time, start at last end
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      final quickCategory = _category == 'Others' && _customCatCtrl.text.trim().isNotEmpty
                          ? _customCatCtrl.text.trim()
                          : _category;
                      if (_category == 'Others' && _customCatCtrl.text.trim().isNotEmpty) {
                        await ref.read(firebaseServiceProvider).addUserCategory(quickCategory);
                      }
                      final base = ActivityModel(
                        activityId: id,
                        activityName: _nameCtrl.text.trim().isEmpty ? 'Activity' : _nameCtrl.text.trim(),
                        startTime: _start,
                        endTime: _start.add(const Duration(hours: 1)),
                        category: quickCategory,
                        source: _source,
                      );
                      await ref.read(firebaseServiceProvider).appendActivityToToday(base);
                      nav.pop(true);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customCatCtrl.dispose();
    super.dispose();
  }

  Future<_ContinuityChoice?> _showContinuityDialog(OverlapInfo info) async {
    bool moveNewStartIfPrev = false; // default: trim previous
    bool moveNextStartIfNext = false; // default: trim new end
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
}

class _ContinuityChoice {
  final bool moveNewStartIfPrev;
  final bool moveNextStartIfNext;
  _ContinuityChoice(this.moveNewStartIfPrev, this.moveNextStartIfNext);
}
