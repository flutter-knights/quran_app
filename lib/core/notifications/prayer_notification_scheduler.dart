import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';

abstract class PrayerNotificationScheduler {
  Future<void> init();

  /// Requests the OS notification permission (Android 13+ POST_NOTIFICATIONS /
  /// iOS alert+sound). Used by first-run onboarding to prompt up front; returns
  /// the grant result (null if unknown/unsupported). Channels and exact-alarm
  /// setup remain in [init], which runs later in the launch pipeline.
  Future<bool?> requestNotificationsPermission();

  /// Whether OS notifications are currently enabled for the app. Drives the
  /// Home notification hint and the resume re-check. Returns false if unknown.
  Future<bool> areNotificationsEnabled();

  Future<DateTime?> scheduleAlerts({
    required List<PrayerTimes> days,
    required Map<PrayerName, PrayerAlert> alerts,
    required String localeCode,
  });

  Future<void> cancelAll();

  Future<void> scheduleTestNotification({Duration delay});
}
