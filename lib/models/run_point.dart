
class RunPoint{
  final DateTime timestamp;
  final LocationSpec location;
  final VibrationSpec vibrationSpec;
  final double orientation;
  final double speed;

  RunPoint({
    required this.timestamp,
    required this.location,
    required this.vibrationSpec, 
    required this.orientation,
    required this.speed
  });

  
  String toPrint() {
    return ("Point:" 
      "\nTime: ${timestamp.toString().split('.').first}" 
      "\nLocation: ${location.toString()}"
      "\nVibration specs: ${vibrationSpec.toString()}"
      "\nOrientation: $orientation°"
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

class VibrationSpec{
  final double xCoordinate;
  final double yCoordinate;
  final double zCoordinate;

  VibrationSpec({
    required this.xCoordinate,
    required this.yCoordinate, 
    required this.zCoordinate, 
  });

  @override
  String toString() {
    return "VibrationSpec<x: $xCoordinate, y: $yCoordinate, z: $zCoordinate>";
  }

  String toPrint() {
    return "Vibration: \n\t x: $xCoordinate \n\t y: $yCoordinate \n\t z: $zCoordinate";
  }

}