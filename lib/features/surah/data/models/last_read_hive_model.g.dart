// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_read_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LastReadHiveModelAdapter extends TypeAdapter<LastReadHiveModel> {
  @override
  final typeId = 5;

  @override
  LastReadHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LastReadHiveModel(
      page: (fields[0] as num).toInt(),
      surah: (fields[1] as num?)?.toInt(),
      ayah: (fields[2] as num?)?.toInt(),
      updatedAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LastReadHiveModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.page)
      ..writeByte(1)
      ..write(obj.surah)
      ..writeByte(2)
      ..write(obj.ayah)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LastReadHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
