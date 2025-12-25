import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/utils/dio_error_handler.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

class PrayerTimesRepositoryImpl extends PrayerTimesRepository {
  final PrayerTimeRemoteDataSource prayerTimeRemoteDataSource;
  final PrayerTimesLocalDataSource prayerTimesLocalDataSource;

  PrayerTimesRepositoryImpl({
    required this.prayerTimeRemoteDataSource,
    required this.prayerTimesLocalDataSource,
  });

  @override
  Future<Either<Failure, PrayerTimes>> getPrayerTimes(Location location) async {
    final cachedPrayerTimes = prayerTimesLocalDataSource.getCached();
    if (cachedPrayerTimes != null) {
      prayerTimesBackgroundPreCache(location);
      return Right(cachedPrayerTimes);
    }
    try {
      final List<PrayerTimes> prayerTimesList = await prayerTimeRemoteDataSource
          .getPrayerTimesList(location);
      await prayerTimesLocalDataSource.cache(prayerTimesList);
      return Right(prayerTimesLocalDataSource.getCached()!);
    } on DioException catch (e) {
      return left(DioErrorHandler.handle(e));
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  Future<void> prayerTimesBackgroundPreCache(Location location) async {
    final now = DateTime.now();
    final DayAfterAfterAfterAfterTomorrow = now.add(const Duration(days: 5));
    final cachedPrayerTimes = prayerTimesLocalDataSource.getCached(
      date: DayAfterAfterAfterAfterTomorrow,
    );
    if (cachedPrayerTimes != null) return;

    try {
      final List<PrayerTimes> prayerTimesList = await prayerTimeRemoteDataSource
          .getPrayerTimesList(location);
      await prayerTimesLocalDataSource.cache(prayerTimesList);
    } catch (e) {
      return;
    }
  }
}
