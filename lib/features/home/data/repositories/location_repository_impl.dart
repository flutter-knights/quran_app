import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/utils/dio_error_handler.dart';
import 'package:quran_app/core/utils/geolocator_error_handler.dart';
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
  Stream<Either<Failure, Location>> getCurrentLocation() async* {
    final cachedLocation = locationLocalDataSource.getCached();

    if (cachedLocation != null) {
      yield Right(cachedLocation);
    }

    try {
      final Position position = await locationRemoteDataSource
          .determinePosition();

      if (isLocationChanged(position)) {
        final Location freshLocation = await locationRemoteDataSource
            .getCurrentLocation(position);
        await locationLocalDataSource.cache(freshLocation);

        yield Right(freshLocation);
      }
    } on LocationException catch (e) {
      if (cachedLocation == null) yield left(GeolocatorErrorHandler.handle(e));
    } on DioException catch (e) {
      if (cachedLocation == null) yield left(DioErrorHandler.handle(e));
    } catch (e) {
      if (cachedLocation == null) yield left(UnknownFailure(e.toString()));
    }
  }

  @override
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
    return distance >= 20000;
  }
}
