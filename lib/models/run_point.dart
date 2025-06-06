
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
  final DimensionalSpec rotationSpec;
  
  @HiveField(4)
  final DimensionalSpec compassSpec;
  //final double orientation;
  
  @HiveField(5)
  final double speed;

  RunPoint({
    required this.timestamp,
    required this.location,
    required this.vibrationSpec,
    required this.rotationSpec,
    required this.compassSpec,
    //required this.orientation,
    required this.speed
  });

  
  String toPrint() {
    return ("Point:" 
      "\nTime: ${timestamp.toString().split('.').first}" 
      "\nLocation: ${location.toString()}"
      "\nVibration specs: ${vibrationSpec.toString()}"
      "\nRotation specs: ${rotationSpec.toString()}"
      "\nCompass specs: ${compassSpec.toString()}"
      //"\nOrientation: $orientation°"
      "\nSpeed: $speed");
  }
}

