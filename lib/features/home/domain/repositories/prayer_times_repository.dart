import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerTimesRepository {
  Future<Either<Failure, PrayerTimes>> getPrayerTimes(Location location);

  /// Pre-caches the given month. Skips network if already fully cached.
  /// Never throws — failures are silently swallowed.
  Future<void> preCacheMonth({
    required Location location,
    required int year,
    required int month,
  });

  /// Reads the cached prayer times for [date] from local storage only — never
  /// hits the network. Returns null when that day is not cached. Used to build
  /// the multi-day pinned-strip window from the already pre-cached month.
  Future<PrayerTimes?> getCachedForDate(DateTime date);
}
