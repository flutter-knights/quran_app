// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hadith_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HadithHiveModelAdapter extends TypeAdapter<HadithHiveModel> {
  @override
  final int typeId = 4;

  @override
  HadithHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HadithHiveModel(
      id: fields[0] as int,
      englishHadith: fields[1] as String,
      arabicHadith: fields[2] as String,
      englishNarrator: fields[3] as String,
      status: fields[4] as String,
      bookId: fields[5] as int,
      pageNumber: fields[6] as int,
      bookSlug: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HadithHiveModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.englishHadith)
      ..writeByte(2)
      ..write(obj.arabicHadith)
      ..writeByte(3)
      ..write(obj.englishNarrator)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.bookId)
      ..writeByte(6)
      ..write(obj.pageNumber)
      ..writeByte(7)
      ..write(obj.bookSlug);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HadithHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
