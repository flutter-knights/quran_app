import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/utils/dio_error_handler.dart';
import 'package:quran_app/core/utils/goelocator_error_handler.dart';
import 'package:quran_app/features/home/data/datasources/location_remote_data_source.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:dartz/dartz.dart';

class LocationRepositoryImpl extends LocationRepository {
  final LocationRemoteDataSource remoteDataSource;
  LocationRepositoryImpl({required this.remoteDataSource});
  @override
  Future<Either<Failure, Location>> getCurrentLocation() async {
    try {
      final Location location = await remoteDataSource.getCurrentLocation();
      return Right(location);
    } on DioException catch (e) {
      return left(DioErrorHandler.handle(e));
    } on LocationException catch (e) {
      return left(GeolocatorErrorHandler.handle(e));
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }
}
