
import 'package:hive/hive.dart';

part 'location_spec.g.dart';

@HiveType(typeId: 2)
class LocationSpec extends HiveObject{
  @HiveField(0)
  final double latitude; 
  @HiveField(1)
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