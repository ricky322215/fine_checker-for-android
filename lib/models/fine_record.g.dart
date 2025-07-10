// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fine_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FineRecordAdapter extends TypeAdapter<FineRecord> {
  @override
  final int typeId = 0;

  @override
  FineRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FineRecord(
      plate: fields[0] as String,
      date: fields[1] as DateTime,
      description: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FineRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.plate)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FineRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
