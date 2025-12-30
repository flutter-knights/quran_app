import 'package:quran_app/features/home/domain/entities/location.dart';

class LocationModel extends Location {
  LocationModel({
    required super.latitude,
    required super.longitude,
    super.country,
    super.city,
    super.enCountry,
    super.enCity,
  });

  factory LocationModel.fromJson({
    required Map<String, dynamic> arJson,
    required Map<String, dynamic> enJson,
  }) {
    final arAddress = arJson['address'];
    final enAddress = enJson['address'];

    return LocationModel(
      latitude: double.parse(arJson['lat']),
      longitude: double.parse(arJson['lon']),
      country: arAddress['country'],
      city: arAddress['city'] ?? arAddress['town'] ?? arAddress['village'],
      enCountry: enAddress['country'],
      enCity: enAddress['city'] ?? enAddress['town'] ?? enAddress['village'],
    );
  }
}
