import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

class GetCachedPrayerDaysParams {
  final DateTime? now;
  final int maxDays;

  const GetCachedPrayerDaysParams({this.now, this.maxDays = 30});
}

class GetCachedPrayerDays
    extends UseCase<List<PrayerTimes>, GetCachedPrayerDaysParams> {
  final PrayerTimesRepository prayerTimesRepository;

  GetCachedPrayerDays({required this.prayerTimesRepository});

  @override
  Future<List<PrayerTimes>> call(GetCachedPrayerDaysParams params) async {
    final now = params.now ?? DateTime.now();
    final days = <PrayerTimes>[];
    for (var i = 0; i < params.maxDays; i++) {
      final day = await prayerTimesRepository.getCachedForDate(
        DateTime(now.year, now.month, now.day + i),
      );
      if (day == null) break;
      days.add(day);
    }
    return days;
  }
}
