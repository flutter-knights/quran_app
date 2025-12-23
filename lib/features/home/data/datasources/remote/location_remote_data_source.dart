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
      // 1. Service check throws specific exception
      throw LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 2. Permission check throws specific exceptions
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

  Future<Location> getCurrentLocation({String languageCode = 'ar'}) async {
    final Position position = await determinePosition();
    final Response locationResponse = await dio.get(
      options: Options(headers: {'User-Agent': 'quran-app/1.0'}),
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': position.latitude,
        'lon': position.longitude,
        'format': 'json',
        'accept-language': languageCode,
      },
    );
    return LocationModel.fromJson(locationResponse.data);
  }
}
