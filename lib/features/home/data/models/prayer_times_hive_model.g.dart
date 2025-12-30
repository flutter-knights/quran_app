// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_times_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrayerTimesHiveModelAdapter extends TypeAdapter<PrayerTimesHiveModel> {
  @override
  final int typeId = 0;

  @override
  PrayerTimesHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrayerTimesHiveModel(
      fajr: fields[0] as String,
      sunrise: fields[1] as String,
      dhuhr: fields[2] as String,
      asr: fields[3] as String,
      maghrib: fields[4] as String,
      isha: fields[5] as String,
      hijriMonth: fields[6] as String,
      hijriWeekDay: fields[7] as String,
      hijriYear: fields[8] as String,
      hijriDay: fields[9] as String,
      key: fields[10] as String,
      enHijriMonth: fields[11] as String,
      enHijriWeekDay: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PrayerTimesHiveModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.fajr)
      ..writeByte(1)
      ..write(obj.sunrise)
      ..writeByte(2)
      ..write(obj.dhuhr)
      ..writeByte(3)
      ..write(obj.asr)
      ..writeByte(4)
      ..write(obj.maghrib)
      ..writeByte(5)
      ..write(obj.isha)
      ..writeByte(6)
      ..write(obj.hijriMonth)
      ..writeByte(7)
      ..write(obj.hijriWeekDay)
      ..writeByte(8)
      ..write(obj.hijriYear)
      ..writeByte(9)
      ..write(obj.hijriDay)
      ..writeByte(10)
      ..write(obj.key)
      ..writeByte(11)
      ..write(obj.enHijriMonth)
      ..writeByte(12)
      ..write(obj.enHijriWeekDay);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTimesHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
