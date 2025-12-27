import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/utils/dio_error_handler.dart';
import 'package:quran_app/core/utils/goelocator_error_handler.dart';
import 'package:quran_app/features/home/data/datasources/local/location_local_data_source.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
import 'package:quran_app/features/home/data/datasources/remote/location_remote_data_source.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:dartz/dartz.dart';

class LocationRepositoryImpl extends LocationRepository {
  final LocationRemoteDataSource locationRemoteDataSource;
  final LocationLocalDataSource locationLocalDataSource;
  final PrayerTimesLocalDataSource prayerTimesLocalDataSource;

  LocationRepositoryImpl({
    required this.locationRemoteDataSource,
    required this.locationLocalDataSource,
    required this.prayerTimesLocalDataSource,
  });
  @override
  Future<Either<Failure, Location>> getCurrentLocation() async {
    final Position position = await locationRemoteDataSource
        .determinePosition();

    final cachedLocation = locationLocalDataSource.getCached();
    if (!isLocationChanged(position)) {
      return Right(cachedLocation!);
    }
    try {
      final Location location = await locationRemoteDataSource
          .getCurrentLocation(position);
      locationLocalDataSource.cache(location);
      return Right(location);
    } on LocationException catch (e) {
      if (cachedLocation != null) return Right(cachedLocation);
      return left(GeolocatorErrorHandler.handle(e));
    } on DioException catch (e) {
      return left(DioErrorHandler.handle(e));
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  bool isLocationChanged(Position? freshLocation) {
    final cachedLocation = locationLocalDataSource.getCached();
    if (cachedLocation == null) return true;
    if (freshLocation == null) return false;

    double distance = Geolocator.distanceBetween(
      freshLocation.latitude,
      freshLocation.longitude,
      cachedLocation.latitude,
      cachedLocation.longitude,
    );
    if (distance < 20000) return false;
    prayerTimesLocalDataSource.clearCache();
    return true;
  }
}
