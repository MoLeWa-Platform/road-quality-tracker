// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RunAdapter extends TypeAdapter<Run> {
  @override
  final int typeId = 0;

  @override
  Run read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Run(
      name: fields[0] as String,
      id: fields[1] as String,
      vehicleType: fields[6] as String,
      startTime: fields[2] as DateTime,
      runPoints: (fields[4] as List).cast<RunPoint>(),
      isSynced: fields[5] as bool,
    )..endTime = fields[3] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, Run obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.runPoints)
      ..writeByte(5)
      ..write(obj.isSynced)
      ..writeByte(6)
      ..write(obj.vehicleType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
