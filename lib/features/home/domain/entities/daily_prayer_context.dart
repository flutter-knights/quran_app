import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class DailyPrayerContext {
  final Location location;
  final PrayerTimes prayerTimes;
  final String date;

  DailyPrayerContext({
    required this.location,
    required this.prayerTimes,
    required this.date,
  });
}
