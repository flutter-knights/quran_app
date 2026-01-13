import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart'; // Required for Position
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';

abstract class LocationRepository {
  Stream<Either<Failure, Location>> getCurrentLocation();

  bool isLocationChanged(Position? freshLocation);
}
