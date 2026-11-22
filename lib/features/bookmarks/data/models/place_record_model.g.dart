// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaceRecordModelAdapter extends TypeAdapter<PlaceRecordModel> {
  @override
  final typeId = 6;

  @override
  PlaceRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaceRecordModel(
      id: fields[0] as String,
      surah: (fields[1] as num).toInt(),
      ayah: (fields[2] as num).toInt(),
      page: (fields[3] as num).toInt(),
      slot: (fields[4] as num?)?.toInt(),
      name: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
      migrated: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PlaceRecordModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.surah)
      ..writeByte(2)
      ..write(obj.ayah)
      ..writeByte(3)
      ..write(obj.page)
      ..writeByte(4)
      ..write(obj.slot)
      ..writeByte(5)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.migrated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceRecordModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
