import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class GetPrayerTimesUseCase {
  Future<PrayerTimes> call(Location location);
}
