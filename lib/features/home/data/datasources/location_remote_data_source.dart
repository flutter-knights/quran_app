import 'package:geolocator/geolocator.dart';
import 'package:quran_app/features/home/data/models/location_model.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:dio/dio.dart';

class LocationRemoteDataSource {
  final Dio dio;
  LocationRemoteDataSource({required this.dio});

  Future<Location> getCurrentLocation({String languageCode = 'ar'}) async {
    final Position position = await Geolocator.getCurrentPosition();
    final Response locationResponse = await dio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': position.latitude,
        'lon': position.longitude,
        'format': 'json',
        'accept-language': languageCode,
      },
    );
    final Location location = LocationModel.fromJson(locationResponse.data);
    return location;
  }
}
