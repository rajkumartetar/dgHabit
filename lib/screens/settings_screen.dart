import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'category_manager_screen.dart';
import '../widgets/sheet_header.dart';

class SettingsScreen extends ConsumerWidget {
  final bool inSheet;
  const SettingsScreen({super.key, this.inSheet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final content = ListView(
      children: [
        if (inSheet)
          SheetHeader(
            title: 'Settings',
            onClose: () => Navigator.of(context).maybePop(),
          ),
        if (inSheet) const SizedBox(height: 8),
        const ListTile(title: Text('Appearance'), dense: true),
        RadioListTile<ThemeMode>(
          title: const Text('System'),
          value: ThemeMode.system,
          groupValue: mode,
          onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Light'),
          value: ThemeMode.light,
          groupValue: mode,
          onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Dark'),
          value: ThemeMode.dark,
          groupValue: mode,
          onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
        ),
        const Divider(height: 24),
        const ListTile(title: Text('Categories'), dense: true),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Manage categories'),
          subtitle: const Text('Add, rename, or remove your custom categories'),
          onTap: () async {
            if (inSheet) {
              // Open Category Manager in a nested bottom sheet for consistent sheet UX
              // ignore: use_build_context_synchronously
              await showModalBottomSheet(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: CategoryManagerScreen(inSheet: true)),
              );
            } else {
              // Fall back to full page push when not in sheet
              // ignore: use_build_context_synchronously
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
              );
            }
          },
        ),
      ],
    );
    if (inSheet) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: content,
    );
  }
}

 
