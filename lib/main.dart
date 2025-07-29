import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:road_quality_tracker/models/run_log.dart';
import 'package:road_quality_tracker/services/background_service.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import 'package:road_quality_tracker/services/run_tracker.dart';

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
  await Hive.initFlutter();
  Hive.registerAdapter(RunAdapter());
  Hive.registerAdapter(RunPointAdapter());
  Hive.registerAdapter(DimensionalSpecAdapter());
  Hive.registerAdapter(LocationSpecAdapter());
  Hive.registerAdapter(RunLogAdapter());
  await Hive.openBox<Run>('runs');

  final runHistory = RunHistoryProvider();

  final runLogger = await RunLogger.create(runHistory);
  final runTracker = RunTracker.create(runLogger);

  final backgroundService = await initService();
  await startServiceAndWait(backgroundService);

  runApp(
    ChangeNotifierProvider(
      create: (_) => runHistory,
      child: RoadQualityTrackerApp(
        backgroundService: backgroundService,
        runLogger: runLogger,
        runTracker: runTracker,
      ),
    ),
  );
}

class RoadQualityTrackerApp extends StatelessWidget {
  final FlutterBackgroundService backgroundService;
  final RunLogger runLogger;
  final RunTracker runTracker;

  const RoadQualityTrackerApp({super.key, required this.backgroundService, required this.runLogger, required this.runTracker});

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
        home: PermissionGate(backgroundService: backgroundService, runLogger: runLogger, runTracker: runTracker),
      ),
    );
  }
}
