import 'package:road_quality_tracker/models/run_point.dart';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

part 'run.g.dart';

@HiveType(typeId: 0)
class Run extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  final String id;

  @HiveField(2)
  final DateTime startTime;

  @HiveField(3)
  DateTime? endTime; 
  
  @HiveField(4)
  final List<RunPoint> runPoints;
  
  @HiveField(5)
  bool isSynced;

  Run({
    required this.name,
    required this.id,
    required this.startTime,
    required this.runPoints,
    required this.isSynced
  });

  factory Run.create(DateTime startTime) {
    final rand = Random(10218).nextInt(10000);
    final id = '${toIsoWithOffset(startTime)}_$rand';
    
    final DateFormat formatter = DateFormat('EEEE, dd.MM.yyyy HH:mm:ss');
    final String formatted = formatter.format(startTime);

    dev.log('created RUN!', name: 'Run');
    return Run(
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

  Map<String, dynamic> toJson() => {
  'id': id,
  'name': name,
  'startTime': toIsoWithOffset(startTime),
  'endTime': toIsoWithOffset(endTime),
  'points': runPoints.map((p) => p.toJson()).toList(),
  };
}