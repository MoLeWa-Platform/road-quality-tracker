// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dimension_spec.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DimensionalSpecAdapter extends TypeAdapter<DimensionalSpec> {
  @override
  final int typeId = 3;

  @override
  DimensionalSpec read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DimensionalSpec(
      type: fields[0] as String,
      xCoordinate: fields[1] as double,
      yCoordinate: fields[2] as double,
      zCoordinate: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DimensionalSpec obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.xCoordinate)
      ..writeByte(2)
      ..write(obj.yCoordinate)
      ..writeByte(3)
      ..write(obj.zCoordinate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DimensionalSpecAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
