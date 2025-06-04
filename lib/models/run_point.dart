
import 'dart:ffi';

class RunPoint{
  final DateTime timestamp;
  final LocationSpec location;
  final DimensionalSpec vibrationSpec;
  final DimensionalSpec rotationSpec;
  final DimensionalSpec compassSpec;
  //final double orientation;
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

class LocationSpec{
  final double latitude; 
  final double longitude;

  LocationSpec({
    required this.latitude, 
    required this.longitude, 
  });

  @override
  String toString() {
    return "Location <lat: ${latitude.toStringAsFixed(6)}, long: ${longitude.toStringAsFixed(6)}>";
  }
  
  String toPrint() {
    return "Location: \n\t latitude: ${latitude.toStringAsFixed(6)} \n\t longitude: ${longitude.toStringAsFixed(6)}";
  }

}

class DimensionalSpec{
  final String type;
  final double xCoordinate;
  final double yCoordinate;
  final double zCoordinate;

  DimensionalSpec({
    required this.type,
    required this.xCoordinate,
    required this.yCoordinate, 
    required this.zCoordinate, 
  });

  @override
  String toString() {
    return "$type<x: $xCoordinate, y: $yCoordinate, z: $zCoordinate>";
  }

  String toPrint() {
    return "$type: \n\t x: $xCoordinate \n\t y: $yCoordinate \n\t z: $zCoordinate";
  }

}