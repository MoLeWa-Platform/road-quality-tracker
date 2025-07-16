import 'package:hive/hive.dart';

part 'dimension_spec.g.dart';

extension DimensionalSpecCopy on DimensionalSpec {
  DimensionalSpec copy() {
    return DimensionalSpec(
      type: type,
      xCoordinate: xCoordinate,
      yCoordinate: yCoordinate,
      zCoordinate: zCoordinate,
    );
  }
}

@HiveType(typeId: 3)
class DimensionalSpec extends HiveObject{
  @HiveField(0)
  final String type;
  @HiveField(1)
  final double xCoordinate;
  @HiveField(2)
  final double yCoordinate;
  @HiveField(3)
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

  Map<String, dynamic> toJson() => {
    //'type': type,
    'x': xCoordinate,
    'y': yCoordinate,
    'z': zCoordinate,
  };
}