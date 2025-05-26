import 'package:road_quality_tracker/models/run_point.dart';
import 'dart:math';
import 'dart:developer' as dev;

class Run {
  final String id;
  final DateTime startTime;
  DateTime? endTime; 
  final List<RunPoint> runPoints;


  Run._({
    required this.id,
    required this.startTime,
    required this.runPoints,
  });

  factory Run.create(DateTime startTime) {
    final rand = Random(10218).nextInt(10000);
    final id = '${startTime.toIso8601String()}_$rand';

    dev.log('created RUN!', name: 'Run');
    return Run._(
      id: id,
      startTime: startTime,
      runPoints: [],
    );
  }
  
  void endRun() {
    endTime = runPoints.last.timestamp;
  }

  void addPoint(RunPoint point) {
    runPoints.add(point);
    dev.log('created Point! ${point.toPrint()}, and list with ${runPoints.length} elements.', name: 'Run');
    
  }
}