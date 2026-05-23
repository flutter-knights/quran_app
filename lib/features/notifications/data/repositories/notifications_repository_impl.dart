import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsNativeDataSource native;
  final PrayerNotificationScheduler legacyScheduler;

  NotificationsRepositoryImpl({
    required this.native,
    required this.legacyScheduler,
  });

  Future<Either<Failure, Unit>> _run(Future<void> Function() body) async {
    try {
      await body();
      return const Right(unit);
    } on PlatformNotImplementedException {
      return const Left(PlatformNotSupportedFailure(
        'Pinned prayer strip is not implemented on this platform yet.',
      ));
    } catch (e) {
      return Left(UnknownNotificationFailure(e.toString()));
    }
  }

  /// Like `_run`, but treats `PlatformNotImplementedException` as a soft
  /// success — used for additive methods (reminders) so a partial native-side
  /// revert never crashes the Dart scheduler.
  Future<Either<Failure, Unit>> _runOptional(
    String label,
    Future<void> Function() body,
  ) async {
    try {
      await body();
      return const Right(unit);
    } on PlatformNotImplementedException {
      debugPrint('[Notifications] $label: native side missing, skipping');
      return const Right(unit);
    } catch (e) {
      return Left(UnknownNotificationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state) =>
      _run(() => native.enableStrip(state));

  @override
  Future<Either<Failure, Unit>> disableStrip() =>
      _run(() => native.disableStrip());

  @override
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state) =>
      _run(() => native.refreshStrip(state));

  @override
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
    required Map<PrayerName, bool> enabledByPrayer,
    required String localeCode,
  }) =>
      _run(() async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final filteredTimings = <PrayerName, String>{
            for (final e in prayerTimes.timings.entries)
              if (enabledByPrayer[e.key] ?? true) e.key: e.value,
          };
          await native.scheduleDailyAdhans(
            timingsByPrayer: _lowercasePrayerKeys(filteredTimings),
            clipAssetByPrayer: _lowercasePrayerKeys(audio.clipAssetByPrayer),
            volume: audio.volume,
            localeCode: localeCode,
          );
        } else {
          await legacyScheduler.scheduleDailyPrayerNotifications(prayerTimes);
        }
      });

  @override
  Future<Either<Failure, Unit>> cancelAllAdhans() =>
      _run(() async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.cancelAllAdhans();
        } else {
          await legacyScheduler.cancelAllPrayerNotifications();
        }
      });

  @override
  Future<Either<Failure, Unit>> schedulePrayerReminders({
    required PrayerTimes prayerTimes,
    required Map<PrayerName, int> reminderMinutesByPrayer,
    required String localeCode,
  }) =>
      _runOptional('schedulePrayerReminders', () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final filtered = <String, int>{
            for (final e in reminderMinutesByPrayer.entries)
              if (e.value > 0) e.key.name.toLowerCase(): e.value,
          };
          await native.schedulePrayerReminders(
            remindersByPrayer: filtered,
            timingsByPrayer: _lowercasePrayerKeys(prayerTimes.timings),
            localeCode: localeCode,
          );
        }
        // iOS path is added in Task 13.
      });

  @override
  Future<Either<Failure, Unit>> cancelAllReminders() =>
      _runOptional('cancelAllReminders', () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.cancelAllReminders();
        }
        // iOS: no-op for now; Task 13 wires legacy scheduler.
      });

  Map<String, String> _lowercasePrayerKeys(Map<PrayerName, String> source) {
    return {for (final e in source.entries) e.key.name.toLowerCase(): e.value};
  }
}
