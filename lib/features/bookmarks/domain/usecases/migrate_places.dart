import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/places_repository.dart';

class MigratePlaces {
  MigratePlaces(this.repository);
  final PlacesRepository repository;

  Future<Either<Failure, Unit>> call() => repository.migrate();
}
