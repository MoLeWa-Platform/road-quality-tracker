import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:road_quality_tracker/main.dart';
import 'package:road_quality_tracker/services/run_history_provider.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import 'package:road_quality_tracker/services/run_tracker.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Create a mock or dummy background service
    final service = FlutterBackgroundService();
    final runHistory = RunHistoryProvider();
    final logger = await RunLogger.create(runHistory);
    final runTracker = RunTracker.create(logger);

    // You don't need to configure it fully for this basic test
    await tester.pumpWidget(RoadQualityTrackerApp(backgroundService: service, runLogger: logger, runTracker: runTracker,));

    // You can now test the existence of a known widget instead
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
