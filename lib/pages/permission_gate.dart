import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:road_quality_tracker/services/version_update.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'home_page.dart';


class PermissionGate extends StatefulWidget {
  final FlutterBackgroundService backgroundService;
  const PermissionGate({super.key, required this.backgroundService});
  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _checkingUpdateAvailable = false;
  bool _allGranted = false;
  bool _initialPermissionCheckDone = false;
  bool _minimumGranted = false;
  num _retries = 1; 
  bool _continue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadContinueFlag();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadContinueFlag() async {
    final box = await Hive.openBox('settings');
    setState(() {
      _continue = box.get('permission_continueAnyway', defaultValue: false);
      _checking = false;
      _checkingUpdateAvailable = true;
    });
    if (_continue) {
      final available = await AppUpdater.updateAvailable();
      if (available == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppUpdater.showUpdateDialog(context);
        });
      }
    }
    setState(() {
      _checkingUpdateAvailable = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_initialPermissionCheckDone) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    _checking = true;
    final result = await getPermissions();

    setState(() {
      _allGranted = result;
      _checking = false;
      _initialPermissionCheckDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme appColorScheme = Theme.of(context).colorScheme;
    if (_checking || _checkingUpdateAvailable) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_allGranted || _continue) {
      return HomePage(backgroundService: widget.backgroundService);
    } else {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                'Road Quality Tracker',
                style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 15),
                Text(
                'Permissions',
                style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 80),
                Icon(Icons.warning_amber_rounded, size: 64, color: appColorScheme.primary),
                const SizedBox(height: 40),
                const Text(
                  "Please activate location services and notifications so the app can function properly.\n\n"
                  "Location services are needed for recording runs.\n"
                  "Notifications will inform you when the app is tracking in the background.\n\n"
                  "Optionally, if you want to download your data, please enable storage permissions.",
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 80),
                (!_initialPermissionCheckDone) ? 
                  ElevatedButton.icon(
                    onPressed: () {
                      _checkPermissions();
                    },
                    icon: const Icon(Icons.verified_user),
                    label: const Text("Ask for Permissions"),
                    style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            elevation: 3,
                          ),
                  ) :
                (_retries > 0) ? 
                  ElevatedButton.icon(
                    onPressed: () {
                      _checkPermissions();
                      _retries--;
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry Permissions"),
                  ) :
                ElevatedButton.icon(
                  onPressed: () {
                    openAppSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text("Open App Settings"),
                ),
                const SizedBox(height: 10),
                if (_minimumGranted)
                Column(
                  children: [
                    const Text("or"),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          updateContinue();
                        });
                      },
                      child: const Text("Continue"),
                    ),
                 ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    }
  }

Future<void> updateContinue() async {
  _continue = true; 
  final box = await Hive.openBox('settings');
  await box.put('permission_continueAnyway', true);
}

Future<bool> getPermissions() async {
  bool allGranted = true;
  bool minimumGranted = true;

  // LOCATION
  var locationStatus = await Permission.location.status;
  if (!locationStatus.isGranted) {
    final result = await Permission.location.request();
    //final result = locationStatus;
    if (!result.isGranted) {
      allGranted = false;
      minimumGranted = false;
      dev.log('Location permission was rejected!', name: 'PermissionService');
    } 
  }

  // NOTIFICATION
  var notificationStatus = await Permission.notification.status;
  if (!notificationStatus.isGranted) {
    final result = await Permission.notification.request();
    if (!result.isGranted) {
      allGranted = false;
      minimumGranted = false;
      dev.log('Notification permission was rejected!', name: 'PermissionService');
    }
  }
  _minimumGranted = minimumGranted;

  // STORAGE (Android-specific)
  if (Platform.isAndroid) {
    final manageStatus = await Permission.manageExternalStorage.status;
    final legacyStatus = await Permission.storage.status;

    if (!manageStatus.isGranted && !legacyStatus.isGranted) {
      final manageResult = await Permission.manageExternalStorage.request();
      if (!manageResult.isGranted) {
        final legacyResult = await Permission.storage.request();
        if (!legacyResult.isGranted) {
          allGranted = false;
          dev.log('Storage permission was rejected!', name: 'PermissionService');
        }
      }
    }
  }

  if (allGranted) {
    dev.log('All Permissions were granted!', name: 'PermissionService');
    updateContinue();
  }


  return allGranted;
}

}
