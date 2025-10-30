import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/sheet_header.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  final bool inSheet;
  const CategoryManagerScreen({super.key, this.inSheet = false});

  @override
  ConsumerState<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen> {
  final TextEditingController _addCtrl = TextEditingController();
  bool _loading = false;

  final List<String> _defaults = const [
    'Personal', 'Hygiene', 'Travel', 'Work', 'Fun', 'Productivity', 'Growth'
  ];

  Future<void> _refresh() async {
    setState(() {});
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(firebaseServiceProvider);
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<String>>(
        future: service.getUserCategories(),
        builder: (context, snap) {
          final customs = (snap.data ?? const <String>[]).where((c) => !_defaults.contains(c)).toList()..sort();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (widget.inSheet)
                SheetHeader(title: 'Manage Categories', onClose: () => Navigator.of(context).maybePop()),
              if (widget.inSheet) const SizedBox(height: 8),
              const ListTile(title: Text('Your categories'), dense: true),
                if (customs.isEmpty)
                  const ListTile(title: Text('No custom categories yet.')), 
                ...customs.map((c) => ListTile(
                      leading: const Icon(Icons.label_outline),
                      title: Text(c),
                      trailing: Wrap(spacing: 8, children: [
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            final newName = await _promptValidated(context, title: 'Rename category', initial: c);
                            if (newName == null || newName.trim().isEmpty || newName.trim() == c) return;
                            // UI dedupe against defaults and customs
                            final existing = await service.getUserCategories();
                            final all = {...existing.map((e) => e.toLowerCase()), ..._defaults.map((e) => e.toLowerCase())};
                            if (all.contains(newName.toLowerCase())) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category already exists')));
                              return;
                            }
                            setState(() => _loading = true);
                            await service.renameUserCategory(from: c, to: newName.trim());
                            setState(() => _loading = false);
                            if (mounted) _refresh();
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            // Prevent deletion if category in use; offer reassign
                            final usage = await service.countActivitiesUsingCategory(c);
                            if (usage > 0) {
                              final res = await _reassignFlow(context, from: c, usageCount: usage);
                              if (res == null) return; // cancelled
                              setState(() => _loading = true);
                              await service.reassignCategory(from: c, to: res);
                              await service.deleteUserCategory(c);
                              setState(() => _loading = false);
                              if (mounted) _refresh();
                            } else {
                              final ok = await _confirm(context, 'Delete "$c"?');
                              if (ok != true) return;
                              setState(() => _loading = true);
                              await service.deleteUserCategory(c);
                              setState(() => _loading = false);
                              if (mounted) _refresh();
                            }
                          },
                        ),
                      ]),
                    )),
              const Divider(height: 24),
              const ListTile(title: Text('Add new category'), dense: true),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addCtrl,
                        decoration: const InputDecoration(hintText: 'e.g., Meditation'),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              final name = _validateName(_addCtrl.text);
                              if (name == null) return;
                              setState(() => _loading = true);
                              await service.addUserCategory(name);
                              _addCtrl.clear();
                              setState(() => _loading = false);
                              if (mounted) _refresh();
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
    if (widget.inSheet) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: body,
    );
  }

  // Removed unused _promptText

  Future<String?> _promptValidated(BuildContext context, {required String title, String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Alphanumeric, 2-24 chars'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final valid = _validateName(ctrl.text);
              if (valid == null) return;
              Navigator.pop(ctx, valid);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
  }

  // Validate, trim, dedupe UI-side
  String? _validateName(String input) {
    final name = input.trim();
    if (name.isEmpty) return null;
    // Allow letters, numbers, spaces; length 2-24
    if (!RegExp(r'^[A-Za-z0-9 ]{2,24}$').hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use 2-24 letters/numbers/spaces')));
      return null;
    }
    // Deduping against defaults and current customs
    final normalized = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  Future<String?> _reassignFlow(BuildContext context, {required String from, required int usageCount}) async {
    final service = ref.read(firebaseServiceProvider);
  final customs = await service.getUserCategories();
  final combined = {..._defaults, ...customs};
  final options = combined.where((c) => c != from).toList()..sort();
    if (options.isEmpty) {
      // no target; ask to create one first
      final newName = await _promptValidated(context, title: 'Create a category to reassign to');
      if (newName == null) return null;
      await service.addUserCategory(newName);
      return newName;
    }
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reassign activities'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$from" is used by $usageCount activities.'),
            const SizedBox(height: 8),
            const Text('Select a category to move them to:'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  children: options.map((opt) => ListTile(
                    title: Text(opt),
                    onTap: () => Navigator.pop(ctx, opt),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }
}
