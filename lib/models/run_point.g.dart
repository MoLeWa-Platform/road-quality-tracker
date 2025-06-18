// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RunPointAdapter extends TypeAdapter<RunPoint> {
  @override
  final int typeId = 1;

  @override
  RunPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RunPoint(
      timestamp: fields[0] as DateTime,
      location: fields[1] as LocationSpec,
      vibrationSpec: fields[2] as DimensionalSpec,
      speed: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RunPoint obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.location)
      ..writeByte(2)
      ..write(obj.vibrationSpec)
      ..writeByte(3)
      ..write(obj.speed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
