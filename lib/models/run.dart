import 'package:road_quality_tracker/models/run_point.dart';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';

class Run {
  String name;
  final String id;
  final DateTime startTime;
  DateTime? endTime; 
  final List<RunPoint> runPoints;
  bool isSynced;


  Run._({
    required this.name,
    required this.id,
    required this.startTime,
    required this.runPoints,
    required this.isSynced
  });

  factory Run.create(DateTime startTime) {
    final rand = Random(10218).nextInt(10000);
    final id = '${startTime.toIso8601String()}_$rand';
    
    final DateFormat formatter = DateFormat('EEEE, dd.MM.yyyy HH:mm:ss');
    final String formatted = formatter.format(startTime);

    dev.log('created RUN!', name: 'Run');
    return Run._(
      name: formatted,
      id: id,
      startTime: startTime,
      runPoints: [],
      isSynced: false,
    );
  }
  
  void endRun() {
    endTime = runPoints.last.timestamp;
  }

  void addPoint(RunPoint point) {
    runPoints.add(point);
    dev.log('created Point! ${point.toPrint()}, and list with ${runPoints.length} elements.', name: 'Run');
    
  }

  void setName(String name){
    this.name = name;
  }
}