
import 'dart:math';

import 'package:hive/hive.dart';
import '../models/dimension_spec.dart';
import '../models/location_spec.dart';

part 'run_point.g.dart';

@HiveType(typeId: 1)
class RunPoint extends HiveObject {
  @HiveField(0)
  final DateTime timestamp;
  
  @HiveField(1)
  final LocationSpec location;
  
  @HiveField(2)
  final DimensionalSpec vibrationSpec;
  
  @HiveField(3)
  final double speed;

  @HiveField(4)
  final double vibMagnitude;

  RunPoint({
    required this.timestamp,
    required this.location,
    required this.vibrationSpec,
    required this.speed,
    required this.vibMagnitude
  });

  
  String toPrint() {
    return ("Point:" 
      "\nTime: ${timestamp.toString().split('.').first}" 
      "\nLocation: ${location.toString()}"
      "\nVibration specs: ${vibrationSpec.toString()}"
      "\nVibration magnitude: $vibMagnitude"
      "\nSpeed: $speed");
  }

  Map<String, dynamic> toJson() => {
    'timestamp': toIsoWithOffset(timestamp),
    'speed': speed,
    'location' : location.toJson(),
    'vibration': vibrationSpec.toJson(), 
    'magnitude' : vibMagnitude
  };

  String getVibMagnitude() {
    final withoutGravity = max(0, vibMagnitude - 9.813);
    return '${withoutGravity.toStringAsFixed(2)} m/s²';
  }
}

  String toIsoWithOffset(DateTime? dt) {
    if (dt != null){
      final duration = dt.timeZoneOffset;
      final hours = duration.inHours.abs().toString().padLeft(2, '0');
      final minutes = (duration.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final sign = duration.isNegative ? '-' : '+';

      final iso = dt.toIso8601String();
      return '$iso$sign$hours:$minutes';
    }
    return '';
  }

