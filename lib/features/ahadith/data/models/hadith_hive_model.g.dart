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
      hadithNumber: fields[0] as String,
      englishHadith: fields[1] as String,
      arabicHadith: fields[2] as String,
      englishNarrator: fields[5] as String,
      arabicHeader: fields[4] as String,
      englishHeader: fields[3] as String,
      status: fields[6] as String,
      pageNumber: fields[7] as int,
      bookSlug: fields[8] as String,
      chapterId: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HadithHiveModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.hadithNumber)
      ..writeByte(1)
      ..write(obj.englishHadith)
      ..writeByte(2)
      ..write(obj.arabicHadith)
      ..writeByte(3)
      ..write(obj.englishHeader)
      ..writeByte(4)
      ..write(obj.arabicHeader)
      ..writeByte(5)
      ..write(obj.englishNarrator)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.pageNumber)
      ..writeByte(8)
      ..write(obj.bookSlug)
      ..writeByte(9)
      ..write(obj.chapterId);
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
