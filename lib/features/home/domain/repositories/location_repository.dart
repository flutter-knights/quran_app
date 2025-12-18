import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';

abstract class LocationRepository {
  Future<Either<Failure, Location>> getCurrentLocation();
}
