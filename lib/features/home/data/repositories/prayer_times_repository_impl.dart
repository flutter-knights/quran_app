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
  Future<Either<Failure, PrayerTimes>> getPrayerTimes(
    Location location,
  ) async {
    final now = DateTime.now();
    final todayData = prayerTimesLocalDataSource.getCached(date: now);

    if (todayData == null) {
      return _fetchAndCacheRemote(location, now);
    }

    final ishaTime = todayData.timings[PrayerName.isha]?.parse24hTime();
    if (ishaTime != null && now.isAfter(ishaTime)) {
      final tomorrowDate = now.add(const Duration(days: 1));
      final tomorrowData =
          prayerTimesLocalDataSource.getCached(date: tomorrowDate);

      if (tomorrowData != null) {
        return Right(
          PrayerTimes(
            key: todayData.key,
            date: todayData.date,
            timings: tomorrowData.timings,
          ),
        );
      }
    }

    return Right(todayData);
  }

  Future<Either<Failure, PrayerTimes>> _fetchAndCacheRemote(
    Location location,
    DateTime targetDate,
  ) async {
    try {
      final List<PrayerTimes> prayerTimesList =
          await prayerTimeRemoteDataSource.getPrayerTimesList(location);
      await prayerTimesLocalDataSource.cache(prayerTimesList);
      final cached = prayerTimesLocalDataSource.getCached(date: targetDate);
      if (cached == null) {
        return left(
          const UnknownFailure(
            'Prayer times unavailable for the requested date.',
          ),
        );
      }
      return Right(cached);
    } on DioException catch (e) {
      return left(DioErrorHandler.handle(e));
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<PrayerTimes?> getCachedForDate(DateTime date) async {
    return prayerTimesLocalDataSource.getCached(date: date);
  }

  @override
  Future<void> preCacheMonth({
    required Location location,
    required int year,
    required int month,
  }) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final cachedKeys = prayerTimesLocalDataSource.getCachedKeysForMonth(
      year: year,
      month: month,
    );
    if (cachedKeys.length >= daysInMonth) return;

    try {
      final List<PrayerTimes> prayerTimesList =
          await prayerTimeRemoteDataSource.getPrayerTimesList(
        location,
        year: year,
        month: month,
      );
      await prayerTimesLocalDataSource.cache(prayerTimesList);
    } catch (_) {
      return;
    }
  }
}
