import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:road_quality_tracker/services/background_service.dart';

import 'services/run_history_provider.dart';
import 'pages/permission_gate.dart';
import 'models/run.dart';
import 'models/run_point.dart';
import 'models/location_spec.dart';
import 'models/dimension_spec.dart';


Future<void> startServiceAndWait(FlutterBackgroundService backgroundService) async {
  final completer = Completer<void>();
  await backgroundService.startService();

  Timer.periodic(const Duration(milliseconds: 100), (timer) async {
    final running = await backgroundService.isRunning();
    if (running) {
      if (!completer.isCompleted) {
        dev.log('service is up', name: 'Main');
        timer.cancel();
        completer.complete();
      }
    }
  });

  return completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      dev.log(
        "Backgroundservice readiness timed out.",
        name: "TrackingPage",
      );
      if (!completer.isCompleted) {
        completer.complete(); 
      }
      return;
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backgroundService = await initService();
  await startServiceAndWait(backgroundService);

  await Hive.initFlutter();
  Hive.registerAdapter(RunAdapter());
  Hive.registerAdapter(RunPointAdapter());
  Hive.registerAdapter(DimensionalSpecAdapter());
  Hive.registerAdapter(LocationSpecAdapter());
  await Hive.openBox<Run>('runs');

  runApp(
    ChangeNotifierProvider(
      create: (_) => RunHistoryProvider(),
      child: RoadQualityTrackerApp(
        backgroundService: backgroundService,
      ), // replace with your root widget
    ),
  );
}

class RoadQualityTrackerApp extends StatelessWidget {
  final FlutterBackgroundService backgroundService;
  const RoadQualityTrackerApp({super.key, required this.backgroundService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RunHistoryProvider(),
      child: MaterialApp(
        title: 'Road Quality Tracker',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: PermissionGate(backgroundService: backgroundService),
      ),
    );
  }
}
