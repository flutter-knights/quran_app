import 'dart:async';

import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/features/home/data/models/location_model.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:dio/dio.dart';

class LocationRemoteDataSource {
  final Dio dio;
  LocationRemoteDataSource({required this.dio});

  Future<Position> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationPermissionDeniedException();
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedForeverException();
    }

    try {
      return await Geolocator.getCurrentPosition();
    } on TimeoutException {
      throw LocationTimeoutException();
    }
  }

  Future<Location> getCurrentLocation(Position position) async {

  final arResponse = await dio.get(
    'https://nominatim.openstreetmap.org/reverse',
    options: Options(headers: {'User-Agent': 'quran-app/1.0'}),
    queryParameters: {
      'lat': position.latitude,
      'lon': position.longitude,
      'format': 'json',
      'accept-language': 'ar',
    },
  );

  final enResponse = await dio.get(
    'https://nominatim.openstreetmap.org/reverse',
    options: Options(headers: {'User-Agent': 'quran-app/1.0'}),
    queryParameters: {
      'lat': position.latitude,
      'lon': position.longitude,
      'format': 'json',
      'accept-language': 'en',
    },
  );

  return LocationModel.fromJson(
    arJson: arResponse.data,
    enJson: enResponse.data,
  );
}

}
