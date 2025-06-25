
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backgroundService = await initService();

  await Hive.initFlutter();
  Hive.registerAdapter(RunAdapter());
  Hive.registerAdapter(RunPointAdapter());
  Hive.registerAdapter(DimensionalSpecAdapter());
  Hive.registerAdapter(LocationSpecAdapter());
  await Hive.openBox<Run>('runs');

  runApp(
    ChangeNotifierProvider(
      create: (_) => RunHistoryProvider(),
      child: RoadQualityTrackerApp(backgroundService: backgroundService), // replace with your root widget
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
          home: PermissionGate(backgroundService: backgroundService,),
        )
    );
  }
}
