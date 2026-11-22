import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/place.dart';
import '../repositories/places_repository.dart';

class SavePlace {
  SavePlace(this.repository);
  final PlacesRepository repository;

  Future<Either<Failure, Unit>> call(Place place) => repository.save(place);
}
