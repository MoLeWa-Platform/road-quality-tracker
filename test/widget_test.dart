import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:road_quality_tracker/main.dart';
import 'package:road_quality_tracker/services/background_service.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Create a mock or dummy background service
    final service = FlutterBackgroundService();

    // You don't need to configure it fully for this basic test
    await tester.pumpWidget(RoadQualityTrackerApp(backgroundService: service));

    // You can now test the existence of a known widget instead
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
