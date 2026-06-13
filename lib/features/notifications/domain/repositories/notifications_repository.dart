import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';

/// Single facade for all notification work — pinned strip + adhan playback +
/// pre-prayer reminders. All methods return `Either<Failure, Unit>`.
abstract class NotificationsRepository {
  Future<Either<Failure, Unit>> enableStrip(PrayerStripWindow window);
  Future<Either<Failure, Unit>> disableStrip();
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripWindow window);

  /// Schedules today's per-prayer adhan notifications.
  /// [enabledByPrayer] filters which prayers receive an adhan.
  /// Replaces any previously scheduled set.
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
    required Map<PrayerName, bool> enabledByPrayer,
    required String localeCode,
  });

  Future<Either<Failure, Unit>> cancelAllAdhans();

  /// Schedules pre-prayer reminder notifications.
  /// [reminderMinutesByPrayer] maps each prayer to a positive offset in
  /// minutes; 0 means no reminder. Replaces any previously scheduled set.
  Future<Either<Failure, Unit>> schedulePrayerReminders({
    required PrayerTimes prayerTimes,
    required Map<PrayerName, int> reminderMinutesByPrayer,
    required String localeCode,
  });

  Future<Either<Failure, Unit>> cancelAllReminders();
}
