import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// Single facade for all notification work — pinned strip + adhan playback.
///
/// All methods return `Either<Failure, Unit>`. A `PlatformNotSupportedFailure`
/// is returned for capabilities not yet implemented on the current platform
/// (notably the pinned strip while only Plan A is shipped). Callers should
/// treat that failure as "feature unavailable on this device" — not as an
/// error to surface to the user, unless explicitly initiated by user action
/// such as toggling the Settings switch.
abstract class NotificationsRepository {
  /// Shows the pinned prayer-times strip with the given snapshot.
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state);

  /// Hides the pinned strip. Idempotent — safe to call when nothing is shown.
  Future<Either<Failure, Unit>> disableStrip();

  /// Re-renders the pinned strip with a new snapshot (e.g., locale change,
  /// midnight rollover, prayer-time crossing). No-op if the strip is hidden.
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state);

  /// Schedules today's per-prayer adhan notifications. Replaces any
  /// previously scheduled set.
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
    required String localeCode,
  });

  /// Cancels all scheduled adhan notifications.
  Future<Either<Failure, Unit>> cancelAllAdhans();
}
