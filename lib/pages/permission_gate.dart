import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as dev;
import 'home_page.dart';


class PermissionGate extends StatefulWidget {
  final FlutterBackgroundService backgroundService;
  const PermissionGate({super.key, required this.backgroundService});
  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver{
  bool _checking = true;
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final result = await getPermissions();
    
    setState(() {
      _granted = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme appColorScheme = Theme.of(context).colorScheme;
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_granted) {
      return HomePage(backgroundService: widget.backgroundService);
    } else {
      return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 64, color: appColorScheme.primary),
              const SizedBox(height: 30),
              const Text(
                "Please activate the required permissions so the app can function properly. Location services are needed for recording runs. Notifications are used to make you aware of background tracking.",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  openAppSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text("Open App Settings"),
              ),
              const SizedBox(height: 40)
            ],
          ),
        ),
      ),
    );
    }
  }
}

Future<bool> getPermissions() async {
  bool allGranted = true;

  // LOCATION
  var locationStatus = await Permission.location.status;
  if (!locationStatus.isGranted) {
    final result = await Permission.location.request();
    if (!result.isGranted) {
      allGranted = false;
      dev.log('Location permission was rejected!', name: 'PermissionService');
    }
  }

  // NOTIFICATION
  var notificationStatus = await Permission.notification.status;
  if (!notificationStatus.isGranted) {
    final result = await Permission.notification.request();
    if (!result.isGranted) {
      allGranted = false;
      dev.log('Notification permission was rejected!', name: 'PermissionService');
    }
  }

  if (allGranted) {
    dev.log('All Permissions were granted!', name: 'PermissionService');
  }

  return allGranted;
}
