import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/place.dart';

abstract class PlacesRepository {
  Future<Either<Failure, List<Place>>> getAll();
  Future<Either<Failure, Unit>> save(Place place);
  Future<Either<Failure, Unit>> remove(String id);
  Future<Either<Failure, Unit>> migrate();
}
