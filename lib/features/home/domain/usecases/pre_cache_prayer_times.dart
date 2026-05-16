import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

class PreCachePrayerTimesParams {
  final Location location;
  final DateTime? now;
  PreCachePrayerTimesParams({required this.location, this.now});
}

class PreCachePrayerTimes extends UseCase<void, PreCachePrayerTimesParams> {
  final PrayerTimesRepository prayerTimesRepository;

  PreCachePrayerTimes({required this.prayerTimesRepository});

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  @override
  Future<void> call(PreCachePrayerTimesParams params) async {
    final now = params.now ?? DateTime.now();

    await prayerTimesRepository.preCacheMonth(
      location: params.location,
      year: now.year,
      month: now.month,
    );

    final daysLeft = _daysInMonth(now.year, now.month) - now.day;
    if (daysLeft <= 7) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      await prayerTimesRepository.preCacheMonth(
        location: params.location,
        year: nextYear,
        month: nextMonth,
      );
    }
  }
}
