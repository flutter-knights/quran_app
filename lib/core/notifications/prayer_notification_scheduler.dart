import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerNotificationScheduler {
  Future<void> init();
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes);
  Future<void> cancelAllPrayerNotifications();

  /// Schedules a single static pre-prayer reminder for [prayer] at [at].
  /// Used on iOS only — Android has its own scheduler with live countdown.
  Future<void> scheduleStaticReminder({
    required PrayerName prayer,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Cancels all pre-prayer reminders that were posted via
  /// [scheduleStaticReminder]. iOS-only callsite.
  Future<void> cancelAllStaticReminders();

  Future<void> scheduleTestNotification({Duration delay});
}
