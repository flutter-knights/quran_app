// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocationHiveModelAdapter extends TypeAdapter<LocationHiveModel> {
  @override
  final int typeId = 2;

  @override
  LocationHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocationHiveModel(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      country: fields[2] as String?,
      city: fields[3] as String?,
      enCity: fields[4] as String?,
      enCountry: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocationHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.country)
      ..writeByte(3)
      ..write(obj.city)
      ..writeByte(4)
      ..write(obj.enCity)
      ..writeByte(5)
      ..write(obj.enCountry);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
