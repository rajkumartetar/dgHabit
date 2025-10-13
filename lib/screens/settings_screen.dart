import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'category_manager_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
