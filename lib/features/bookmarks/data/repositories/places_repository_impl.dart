import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/places_repository.dart';
import '../datasources/local/places_local_data_source.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  PlacesRepositoryImpl({required this.dataSource});
  final PlacesLocalDataSource dataSource;

  @override
  Future<Either<Failure, List<Place>>> getAll() async {
    try {
      return Right(dataSource.getAll());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(Failure.fromException(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> save(Place place) async {
    try {
      await dataSource.save(place);
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(Failure.fromException(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> remove(String id) async {
    try {
      await dataSource.remove(id);
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(Failure.fromException(e));
    }
  }
}
