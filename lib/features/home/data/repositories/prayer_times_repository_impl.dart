import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
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
    final todayData = prayerTimesLocalDataSource.getCached(
      date: DateTime.now(),
    );

    DateTime targetDate = DateTime.now();

    if (todayData != null) {
      final ishaTime = todayData.timings[PrayerName.isha]!.parse24hTime();

      if (DateTime.now().isAfter(ishaTime)) {
        targetDate = DateTime.now().add(const Duration(days: 1));
      }
    }

    final cachedPrayerTimes = prayerTimesLocalDataSource.getCached(
      date: targetDate,
    );
    if (cachedPrayerTimes != null) {
      prayerTimesBackgroundPreCache(location);
      return Right(cachedPrayerTimes);
    }
    try {
      final List<PrayerTimes> prayerTimesList = await prayerTimeRemoteDataSource
          .getPrayerTimesList(location);
      await prayerTimesLocalDataSource.cache(prayerTimesList);
      return Right(prayerTimesLocalDataSource.getCached(date: targetDate)!);
    } on DioException catch (e) {
      return left(DioErrorHandler.handle(e));
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  Future<void> prayerTimesBackgroundPreCache(Location location) async {
    final now = DateTime.now();
    final dayAfterAfterAfterAfterTomorrow = now.add(const Duration(days: 5));
    final cachedPrayerTimes = prayerTimesLocalDataSource.getCached(
      date: dayAfterAfterAfterAfterTomorrow,
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
