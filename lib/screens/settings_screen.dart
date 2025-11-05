import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'category_manager_screen.dart';
import '../widgets/sheet_header.dart';
import '../services/background_tasks.dart';
import '../services/app_info_channel.dart';
import '../services/system_channel.dart';
import 'dart:io' show Platform;

class SettingsScreen extends ConsumerWidget {
  final bool inSheet;
  const SettingsScreen({super.key, this.inSheet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final notifPrefs = ref.watch(notificationPrefsProvider);
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
        const Divider(height: 24),
        const ListTile(title: Text('Notifications'), dense: true),
        SwitchListTile.adaptive(
          title: const Text('Enable reminders'),
          value: notifPrefs.enabled,
          onChanged: (v) async {
            await ref.read(notificationPrefsProvider.notifier).setEnabled(v);
            if (v) {
              await ref.read(notificationServiceProvider).initialize();
            } else {
              await ref.read(notificationServiceProvider).cancelAll();
            }
          },
        ),
        ListTile(
          title: const Text('Inactivity reminder'),
          subtitle: Text('Every ${notifPrefs.inactivityHours} hour(s)'),
          trailing: DropdownButton<int>(
            value: notifPrefs.inactivityHours,
            items: const [1,2,3,4,6,8,12].map((h) => DropdownMenuItem(value: h, child: Text('$h h'))).toList(),
            onChanged: (v) async {
              if (v == null) return;
              await ref.read(notificationPrefsProvider.notifier).setInactivityHours(v);
              if (notifPrefs.enabled) {
                // Simple approach: cancel and re-schedule hourly periodic with plugin limitation
                await ref.read(notificationServiceProvider).cancel(200);
                await ref.read(notificationServiceProvider).scheduleInactivityPeriodic(Duration(hours: v));
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Developer testing buttons removed for production readiness
              Expanded(child: SizedBox.shrink()),
              const SizedBox(width: 12),
              Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
        const Divider(height: 24),
        const ListTile(title: Text('Screen time limits'), dense: true),
        if (Platform.isAndroid)
          ListTile(
            leading: const Icon(Icons.lock_clock),
            title: const Text('Open Usage Access settings'),
            subtitle: const Text('Grant or review app usage permission'),
            onTap: () async {
              final ok = await SystemChannel().openUsageAccessSettings();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open settings. You can find it under Settings > Security & privacy > Special app access > Usage access.')),
                );
              }
            },
          ),
        ListTile(
          title: const Text('Per-app screen time alerts'),
          subtitle: Text(
            notifPrefs.perAppLimits.isEmpty
                ? 'No apps configured'
                : '${notifPrefs.perAppLimits.length} app(s) configured',
          ),
          trailing: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add app limit'),
            onPressed: () async {
              // Build a simple dialog to pick from today’s usage
              final now = DateTime.now();
              final start = DateTime(now.year, now.month, now.day);
              final sensor = ref.read(sensorServiceProvider);
              final map = await sensor.getPerAppScreenTimeMap(start, now) ?? {};
              final pkgs = map.keys.where((k) => k.isNotEmpty).toList()..sort();
              final appInfo = await AppInfoChannel().fetchMany(pkgs);
              // Filter out system apps using channel metadata
              final userPkgs = pkgs.where((pkg) => (appInfo[pkg]?.isSystem ?? false) == false).toList();
              if (userPkgs.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No user apps detected from today\'s usage. Open some apps and try again.')),
                  );
                }
                return;
              }
              if (!context.mounted) return;
              String? selected;
              int limit = 60;
              await showDialog(
                context: context,
                builder: (ctx) {
                  String query = '';
                  return StatefulBuilder(builder: (ctx, setState) {
                    final filtered = userPkgs.where((pkg) => appInfo[pkg]!.name.toLowerCase().contains(query.toLowerCase())).toList();
                    return AlertDialog(
                      title: const Text('Add per-app limit'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Search apps',
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() {
                                query = v;
                                if (selected != null && !appInfo[selected!]!.name.toLowerCase().contains(v.toLowerCase())) {
                                  selected = null;
                                }
                              }),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selected,
                              isExpanded: true,
                              selectedItemBuilder: (ctx) => filtered
                                  .map((pkg) => Text(
                                        appInfo[pkg]!.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ))
                                  .toList(),
                              items: filtered.map((pkg) {
                                final info = appInfo[pkg]!;
                                return DropdownMenuItem(
                                  value: pkg,
                                  child: Text(info.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (v) => selected = v,
                              decoration: const InputDecoration(
                                hintText: 'Select app',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: limit,
                              items: const [15,30,45,60,90,120,180,240].map((m) => DropdownMenuItem(value: m, child: Text('$m minutes'))).toList(),
                              onChanged: (v) => limit = v ?? limit,
                              decoration: const InputDecoration(labelText: 'Daily limit'),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () {
                            if (selected != null) {
                              Navigator.pop(ctx, true);
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    );
                  });
                },
              );
              if (selected != null) {
                await ref.read(notificationPrefsProvider.notifier).setPerAppLimit(selected!, limit);
                if (notifPrefs.backgroundScreenChecks) {
                  await scheduleScreenCheckPeriodic();
                }
              }
            },
          ),
        ),
        if (notifPrefs.perAppLimits.isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FutureBuilder<Map<String, AppInfoItem>>(
              future: AppInfoChannel().fetchMany(notifPrefs.perAppLimits.keys),
              builder: (context, snap) {
                final infoMap = snap.data ?? { for (final p in notifPrefs.perAppLimits.keys) p: AppInfoItem(package: p, name: p) };
                return Column(
                  children: notifPrefs.perAppLimits.entries.map((e) {
                    final info = infoMap[e.key] ?? AppInfoItem(package: e.key, name: e.key);
                    return ListTile(
                      leading: info.icon != null ? CircleAvatar(backgroundImage: MemoryImage(info.icon!)) : const Icon(Icons.apps),
                      title: Text(info.name),
                      subtitle: Text('${e.key} • Limit: ${e.value} min/day'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await ref.read(notificationPrefsProvider.notifier).removePerAppLimit(e.key);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        SwitchListTile.adaptive(
          title: const Text('Automatic background checks (Android)'),
          subtitle: const Text('Periodically alert when limit exceeded'),
          value: notifPrefs.backgroundScreenChecks,
          onChanged: (v) async {
            await ref.read(notificationPrefsProvider.notifier).setBackgroundScreenChecks(v);
            // Schedule or cancel background task based on prefs
            if (v) {
              await initWorkmanager();
              await scheduleScreenCheckPeriodic();
            } else {
              await cancelScreenCheck();
            }
          },
        ),
        ListTile(
          title: const Text('This app daily limit'),
          subtitle: Text('${notifPrefs.screenTimeLimitMinutes} min'),
          trailing: DropdownButton<int>(
            value: notifPrefs.screenTimeLimitMinutes,
            items: const [30, 60, 90, 120, 180, 240].map((m) => DropdownMenuItem(value: m, child: Text('$m m'))).toList(),
            onChanged: (v) async {
              if (v == null) return;
              await ref.read(notificationPrefsProvider.notifier).setScreenTimeLimit(v);
              if (notifPrefs.backgroundScreenChecks) {
                await scheduleScreenCheckPeriodic();
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: () async {
              // On-demand check for this app's screen time today
              final sensor = ref.read(sensorServiceProvider);
              final now = DateTime.now();
              final start = DateTime(now.year, now.month, now.day);
              final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
              try {
                final dur = await sensor.getThisAppScreenTime(start, end);
                final minutes = (dur?.inMinutes ?? 0).toDouble();
                if (minutes >= notifPrefs.screenTimeLimitMinutes) {
                  await ref.read(notificationServiceProvider).showNow(
                        title: 'Screen time limit',
                        body: 'You\'ve used ${minutes.toStringAsFixed(0)} min today (limit ${notifPrefs.screenTimeLimitMinutes} min).',
                      );
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Used ${minutes.toStringAsFixed(0)} min today (limit ${notifPrefs.screenTimeLimitMinutes} min).')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to read screen time: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.timelapse_outlined),
            label: const Text('Check today\'s usage now'),
          ),
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

 
