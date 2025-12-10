import 'package:quran_app/features/home/domain/entities/location.dart';

class LocationModel extends Location {
  LocationModel({
    required super.latitude,
    required super.longitude,
    super.country,
    super.city,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    return LocationModel(
      latitude: double.parse(json['lat']),
      longitude: double.parse(json['lon']),
      country: address['country'],
      city: address['city'] ?? address['town'] ?? address['village'],
    );
  }
}
