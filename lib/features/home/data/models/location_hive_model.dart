import 'package:hive/hive.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';

part 'location_hive_model.g.dart';

@HiveType(typeId: 2)
class LocationHiveModel extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final String? country;

  @HiveField(3)
  final String? city;
  @HiveField(4)
  final String? enCity;
  @HiveField(5)
  final String? enCountry;

  LocationHiveModel({
    required this.latitude,
    required this.longitude,
    this.country,

    this.city,
    this.enCity,
    this.enCountry,
  });
}

extension LocationEntityMapper on Location {
  LocationHiveModel toHive() {
    return LocationHiveModel(
      latitude: latitude,
      longitude: longitude,
      country: country,
      enCity: enCity,
      city: city,
      enCountry: enCountry,
    );
  }
}

extension LocationHiveMapper on LocationHiveModel {
  Location toEntity() {
    return Location(
      latitude: latitude,
      longitude: longitude,
      country: country,
      city: city,
      enCity: enCity,
      enCountry: enCountry,
    );
  }
}
