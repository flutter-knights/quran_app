import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerTimesRepository {
  Future<Either<Failure, PrayerTimes>> getPrayerTimes(
    Location location, {
    int method = 3,
    int school = 0,
  });

  /// Pre-caches the given month. Skips network if already fully cached.
  /// Never throws — failures are silently swallowed.
  Future<void> preCacheMonth({
    required Location location,
    required int year,
    required int month,
    int method = 3,
    int school = 0,
  });
}
