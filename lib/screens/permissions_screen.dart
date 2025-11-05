import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dghabit/third_party/usage_stats.dart' as us;
import '../widgets/sheet_header.dart';

class PermissionsScreen extends StatefulWidget {
  final bool inSheet;
  const PermissionsScreen({super.key, this.inSheet = false});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool? activityGranted;
  bool? usageGranted;
  bool? cameraGranted;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!Platform.isAndroid) {
      setState(() {
        activityGranted = true;
        usageGranted = true;
        cameraGranted = true;
      });
      return;
    }
    final act = await Permission.activityRecognition.status;
    final usage = await us.UsageStats.checkUsagePermission();
    final cam = await Permission.camera.status;
    setState(() {
      activityGranted = act.isGranted;
      usageGranted = usage;
      cameraGranted = cam.isGranted;
    });
  }

  Future<void> _requestActivity() async {
    if (!Platform.isAndroid) return;
    final res = await Permission.activityRecognition.request();
    setState(() => activityGranted = res.isGranted);
  }

  Future<void> _requestCamera() async {
    if (!Platform.isAndroid) return;
    final res = await Permission.camera.request();
    setState(() => cameraGranted = res.isGranted);
  }

  Future<void> _openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    await us.UsageStats.grantUsagePermission();
    await Future.delayed(const Duration(seconds: 1));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.inSheet) SheetHeader(title: 'Permissions', onClose: () => Navigator.of(context).maybePop()),
          if (widget.inSheet) const SizedBox(height: 8),
          // Camera first
          ListTile(
            leading: Icon(cameraGranted == true ? Icons.check_circle : Icons.error, color: cameraGranted == true ? Colors.green : Colors.orange),
            title: const Text('Camera (meal photos)'),
            subtitle: const Text('Allow to capture photos for meals'),
            trailing: ElevatedButton(
              onPressed: cameraGranted == true ? null : _requestCamera,
              child: Text(cameraGranted == true ? 'Granted' : 'Grant'),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(activityGranted == true ? Icons.check_circle : Icons.error, color: activityGranted == true ? Colors.green : Colors.orange),
            title: const Text('Physical Activity (steps)'),
            subtitle: const Text('Allow to read step count from sensors'),
            trailing: ElevatedButton(
              onPressed: activityGranted == true ? null : _requestActivity,
              child: Text(activityGranted == true ? 'Granted' : 'Grant'),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(usageGranted == true ? Icons.check_circle : Icons.error, color: usageGranted == true ? Colors.green : Colors.orange),
            title: const Text('Usage Access (screen time)'),
            subtitle: const Text('Open settings to grant Usage Access'),
            trailing: ElevatedButton(
              onPressed: usageGranted == true ? null : _openUsageAccessSettings,
              child: Text(usageGranted == true ? 'Granted' : 'Open Settings'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Re-check')),
        ],
      ),
    );
    if (widget.inSheet) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: body,
    );
  }
}
 
