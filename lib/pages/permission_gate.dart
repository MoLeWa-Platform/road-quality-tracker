import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import 'package:road_quality_tracker/services/run_tracker.dart';
import 'package:road_quality_tracker/services/version_update.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'home_page.dart';

class PermissionGate extends StatefulWidget {
  final FlutterBackgroundService backgroundService;
  final RunLogger runLogger;
  final RunTracker runTracker;

  const PermissionGate({
    super.key,
    required this.backgroundService,
    required this.runLogger,
    required this.runTracker,
  });
  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _checkingUpdateAvailable = false;
  bool _allGranted = false;
  bool _initialPermissionCheckDone = false;
  bool _minimumGranted = false;
  bool _continue = false;
  bool _sentToLocationSettings=false;
  bool _sentToLocationBSettings = false;
  bool _sentToNotificationSettings = false;
  bool _sentToBatterySettings = false;
  bool _sentToStorageSettings = false;
  bool _permissionDialogActive = false;

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
      _continue = box.get('permission_continueAnyway2', defaultValue: false);
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

  Future<void> showBatteryOptimizationDialog(BuildContext context) async {
    const packageName = 'com.molewa.roadqualitytracker'; // update if different

    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:$packageName',
    );

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Battery Optimisation"),
            content: const Text(
              "To ensure smooth tracking, please disable battery optimization for this app.",
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Ok"),
                onPressed: () async {
                  try {
                    Navigator.pop(context);
                    await intent.launch();
                  } catch (e) {
                    debugPrint("Failed to launch intent: $e");
                  }
                },
              ),
            ],
          ),
    );
  }

  Future<void> showLocationAlwaysDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("Background Location Required"),
            content: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: const [
                  TextSpan(
                    text:
                        "To track road quality while the screen is off or the app is in the background, please enable 'Allow all the time' location access in system settings. ",
                  ),
                  TextSpan(text: "\n \nTo do so in the next screen, tap "),
                  TextSpan(
                    text: "\nPermissions > Location > Allow all the time",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: "."),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                child: const Text("Open Settings"),
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await openAppSettings();
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme appColorScheme = Theme.of(context).colorScheme;
    if (_checking || _checkingUpdateAvailable) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_allGranted || _continue) {
      return HomePage(
        backgroundService: widget.backgroundService,
        runLogger: widget.runLogger,
        runTracker: widget.runTracker,
      );
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
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: appColorScheme.primary,
                ),
                const SizedBox(height: 40),
                const Text(
                  "Please activate location services and notifications so the app can function properly.\n\n\n"
                  "Location services are needed for recording runs.\n\n"
                  "Background tracking needs the permission to send you notifications and turned off battery optimisation.\n\n"
                  "Optionally, if you want to download your data, please enable storage permissions.",
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 80),
                (!_initialPermissionCheckDone)
                    ? ElevatedButton.icon(
                      onPressed: () {
                        _checkPermissions();
                      },
                      icon: const Icon(Icons.verified_user),
                      label: const Text("Ask for Permissions"),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        elevation: 3,
                      ),
                    )
                    : ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _sentToLocationSettings = false;
                          _sentToLocationBSettings = false;
                          _sentToNotificationSettings = false;
                          _sentToStorageSettings = false;
                          _sentToBatterySettings = false;
                        });
                        _checkPermissions();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry Permissions"),
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
    await box.put('permission_continueAnyway2', true);
  }

  Future<bool> getPermissions() async {
    bool allGranted = true;
    bool minimumGranted = true;
    const int delay = 300;

    // LOCATION
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted && !_sentToLocationSettings) {
      _sentToLocationSettings = true;
      _permissionDialogActive = true;
      final result = await Permission.location.request();
      _permissionDialogActive = false;
      if (!result.isGranted) {
        allGranted = false;
        minimumGranted = false;
        dev.log('Location permission was rejected!', name: 'PermissionService');
      }
    }
    
    while (_permissionDialogActive){
      await Future.delayed(const Duration(milliseconds: delay));
    }

    // BACKGROUND LOCATION (Android only)
    if (Platform.isAndroid) {
      final backgroundStatus = await Permission.locationAlways.status;

      if (!backgroundStatus.isGranted && !_sentToLocationBSettings) {
        _sentToLocationBSettings = true;
        if (mounted) {
          _permissionDialogActive = true;
          await showLocationAlwaysDialog(context);
          _permissionDialogActive = false;
        }
      }

      final recheck = await Permission.locationAlways.status;
      if (!recheck.isGranted) {
        allGranted = false;
        minimumGranted = false;
        dev.log(
          'Background location permission still not granted!',
          name: 'PermissionService',
        );
      }
    }

    while (_permissionDialogActive){
      await Future.delayed(const Duration(milliseconds: delay));
    }

    // NOTIFICATION
    var notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted && !_sentToNotificationSettings) {
      _sentToNotificationSettings = true;
      _permissionDialogActive = true;
      final result = await Permission.notification.request();
      _permissionDialogActive = false;
      if (!result.isGranted) {
        allGranted = false;
        minimumGranted = false;
        dev.log(
          'Notification permission was rejected!',
          name: 'PermissionService',
        );
      }
    }

    while (_permissionDialogActive){
      await Future.delayed(const Duration(milliseconds: delay));
    }

    // STORAGE (Android-specific)
    if (Platform.isAndroid) {
      final manageStatus = await Permission.manageExternalStorage.status;
      final legacyStatus = await Permission.storage.status;

      if (!_sentToStorageSettings) {
        _sentToStorageSettings = true;
        if (!manageStatus.isGranted && !legacyStatus.isGranted) {
          _permissionDialogActive = true;
          final manageResult = await Permission.manageExternalStorage.request();
          _permissionDialogActive = false;
          if (!manageResult.isGranted) {
            _permissionDialogActive = true;
            final legacyResult = await Permission.storage.request();
            _permissionDialogActive = false;
            if (!legacyResult.isGranted) {
              allGranted = false;
              dev.log(
                'Storage permission was rejected!',
                name: 'PermissionService',
              );
            }
          }
        }
      }
    }

    while (_permissionDialogActive){
      await Future.delayed(const Duration(milliseconds: delay));
    }

    // Battery optimization
    if (!await Permission.ignoreBatteryOptimizations.isGranted &&
        !_sentToBatterySettings) {
      if (mounted) {
        _sentToBatterySettings = true;
        _permissionDialogActive = true;
        await showBatteryOptimizationDialog(context);
        _permissionDialogActive = false;
      }
    }
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      allGranted = false;
      minimumGranted = false;
    }

    _minimumGranted = minimumGranted;

    if (allGranted) {
      dev.log('All Permissions were granted!', name: 'PermissionService');
      updateContinue();
    }

    return allGranted;
  }
}
