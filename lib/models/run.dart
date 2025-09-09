import 'package:road_quality_tracker/models/run_point.dart';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

part 'run.g.dart';

extension RunCopy on Run {
  Run copy() {
    return Run(
      id: id,
      name: name,
      startTime: startTime,
      endTime: endTime,
      vehicleType: vehicleType,
      runPoints: List<RunPoint>.from(runPoints.map((p) => p.copy())), 
      isSynced: isSynced,
      tags: List<String>.from(tags)
    );
}
}

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

  @HiveField(6)
  String vehicleType;

  @HiveField(7)
  List<String> tags;

  Run({
    required this.name,
    required this.id,
    required this.vehicleType,
    required this.startTime,
    required this.runPoints,
    required this.isSynced,
    this.endTime,
    List<String>? tags,              
  }) : tags = tags ?? <String>[];

  factory Run.create(DateTime startTime, String vehicleType) {
    final rand = Random(10218).nextInt(10000);
    final id = '${toIsoWithOffset(startTime)}_$rand';
    
    final DateFormat formatter = DateFormat('EEEE, dd.MM.yyyy HH:mm:ss');
    final String formatted = formatter.format(startTime);

    dev.log('Created RUN!', name: 'Run');
    return Run(
      name: formatted,
      id: id,
      vehicleType: vehicleType,
      startTime: startTime,
      runPoints: [],
      isSynced: false,
      tags: <String>[],
    );
  }
  
  void setEndTime() {
    endTime = runPoints.last.timestamp;
  }

  void addPoint(RunPoint point) {
    runPoints.add(point);
    dev.log('Created Point! Run list has ${runPoints.length} elements.', name: 'Run');
    
  }

  void setName(String name){
    this.name = name;
  }

  Map<String, dynamic> toJson() => {
  'id': id,
  'name': name,
  'vehicleType': vehicleType,
  'startTime': toIsoWithOffset(startTime),
  'endTime': toIsoWithOffset(endTime),
  'tags': tags,
  'points': runPoints.map((p) => p.toJson()).toList(),
  };

  String getFormattedDuration({live=false}) { 
    if (endTime==null){
      if (runPoints.isNotEmpty) {
        setEndTime();
      }
    }
    final end =  (endTime==null || live) ?  DateTime.now() : endTime;
    final duration = end!.difference(startTime);
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }
}