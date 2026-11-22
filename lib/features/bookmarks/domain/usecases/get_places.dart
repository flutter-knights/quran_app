import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/place.dart';
import '../repositories/places_repository.dart';

class GetPlaces {
  GetPlaces(this.repository);
  final PlacesRepository repository;

  Future<Either<Failure, List<Place>>> call() => repository.getAll();
}
