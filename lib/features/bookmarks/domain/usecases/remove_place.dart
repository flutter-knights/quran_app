import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/places_repository.dart';

class RemovePlace {
  RemovePlace(this.repository);
  final PlacesRepository repository;

  Future<Either<Failure, Unit>> call(String id) => repository.remove(id);
}
