import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerNotificationScheduler {
  Future<void> init();
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes);
  Future<void> cancelAllPrayerNotifications();
}
