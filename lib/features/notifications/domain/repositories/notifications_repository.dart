import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';

/// Single facade for all notification work — pinned strip + adhan playback +
/// pre-prayer reminders.
abstract class NotificationsRepository {
  Future<Either<Failure, Unit>> enableStrip(PrayerStripWindow window);
  Future<Either<Failure, Unit>> disableStrip();
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripWindow window);

  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required List<PrayerTimes> days,
    required Map<PrayerName, PrayerAlert> alerts,
    required String localeCode,
  });

  Future<Either<Failure, Unit>> cancelAllAdhans();

  Future<Either<Failure, Unit>> schedulePrayerReminders({
    required List<PrayerTimes> days,
    required Map<PrayerName, PrayerAlert> alerts,
    required String localeCode,
  });

  Future<Either<Failure, Unit>> cancelAllReminders();

  Future<Either<Failure, Unit>> scheduleTestAdhan({
    required PrayerAlert alert,
    required String localeCode,
    Duration delay = const Duration(seconds: 5),
  });

  Future<Either<Failure, ReliabilityStatus>> getReliabilityStatus();
  Future<Either<Failure, Unit>> ackMissedAlerts();
  Future<Either<Failure, Unit>> openSystemSettings(SystemSettingsTarget target);
  Future<Either<Failure, Unit>> previewSound({
    required PreviewSound sound,
    required PrayerName prayer,
  });
  Future<Either<Failure, Unit>> stopPreview();
}
