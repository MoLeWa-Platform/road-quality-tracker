// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RunLogAdapter extends TypeAdapter<RunLog> {
  @override
  final int typeId = 10;

  @override
  RunLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RunLog(
      runId: fields[0] as String,
      startTime: fields[1] as DateTime,
      reviewed: fields[6] as bool,
    )
      ..endTime = fields[2] as DateTime?
      ..recentPoints = (fields[3] as List).cast<DateTime>()
      ..warnings = (fields[4] as List).cast<String>()
      ..fullLog = (fields[5] as List).cast<String>();
  }

  @override
  void write(BinaryWriter writer, RunLog obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.runId)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.recentPoints)
      ..writeByte(4)
      ..write(obj.warnings)
      ..writeByte(5)
      ..write(obj.fullLog)
      ..writeByte(6)
      ..write(obj.reviewed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
