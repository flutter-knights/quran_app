import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerNotificationScheduler {
  Future<void> init();
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes);
  Future<void> cancelAllPrayerNotifications();

  /// Debug-only: fires a one-off "Adhan test" notification [delay] from now,
  /// going through the same channel/sound/scheduling path as real prayer
  /// notifications. Used to verify background delivery without waiting for
  /// an actual prayer time.
  Future<void> scheduleTestNotification({Duration delay});
}
