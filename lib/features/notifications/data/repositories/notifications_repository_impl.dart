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
    required List<PrayerTimes> days,
    required AdhanAudioSettings audio,
    required Map<PrayerName, bool> enabledByPrayer,
    required String localeCode,
  }) =>
      _run(() async {
        if (days.isEmpty) return;
        if (defaultTargetPlatform == TargetPlatform.android) {
          final daysPayload = [
            for (final pt in days)
              {
                'date': _toIsoDate(pt.date.gregorianDate),
                'timings': {
                  for (final e in pt.timings.entries)
                    if (enabledByPrayer[e.key] ?? true)
                      e.key.name.toLowerCase(): e.value,
                },
              },
          ];
          await native.scheduleDailyAdhans(
            days: daysPayload,
            clipAssetByPrayer: _lowercasePrayerKeys(audio.clipAssetByPrayer),
            volume: audio.volume,
            localeCode: localeCode,
          );
        } else {
          await legacyScheduler
              .scheduleDailyPrayerNotifications(days.first);
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
    required List<PrayerTimes> days,
    required Map<PrayerName, int> reminderMinutesByPrayer,
    required String localeCode,
  }) =>
      _runOptional('schedulePrayerReminders', () async {
        if (days.isEmpty) return;
        if (defaultTargetPlatform == TargetPlatform.android) {
          final filtered = <String, int>{
            for (final e in reminderMinutesByPrayer.entries)
              if (e.value > 0) e.key.name.toLowerCase(): e.value,
          };
          final daysPayload = [
            for (final pt in days)
              {
                'date': _toIsoDate(pt.date.gregorianDate),
                'timings': {
                  for (final e in pt.timings.entries)
                    e.key.name.toLowerCase(): e.value,
                },
              },
          ];
          await native.schedulePrayerReminders(
            days: daysPayload,
            remindersByPrayer: filtered,
            localeCode: localeCode,
          );
        } else {
          final prayerTimes = days.first;
          await legacyScheduler.cancelAllStaticReminders();
          final date = _parseGregorian(prayerTimes.date.gregorianDate);
          if (date == null) return;
          for (final e in reminderMinutesByPrayer.entries) {
            if (e.value <= 0) continue;
            final hhmm = prayerTimes.timings[e.key];
            if (hhmm == null) continue;
            final parts = hhmm.split(':');
            if (parts.length != 2) continue;
            final hour = int.tryParse(parts[0]);
            final minute = int.tryParse(parts[1]);
            if (hour == null || minute == null) continue;
            final prayerAt =
                DateTime(date.year, date.month, date.day, hour, minute);
            final at = prayerAt.subtract(Duration(minutes: e.value));
            await legacyScheduler.scheduleStaticReminder(
              prayer: e.key,
              at: at,
              title: _prayerNameLocalized(e.key, localeCode),
              body: _reminderBody(e.key, e.value, localeCode),
            );
          }
        }
      });

  @override
  Future<Either<Failure, Unit>> cancelAllReminders() =>
      _runOptional('cancelAllReminders', () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.cancelAllReminders();
        } else {
          await legacyScheduler.cancelAllStaticReminders();
        }
      });

  Map<String, String> _lowercasePrayerKeys(Map<PrayerName, String> source) {
    return {for (final e in source.entries) e.key.name.toLowerCase(): e.value};
  }

  DateTime? _parseGregorian(String s) {
    // PrayerTimes.date.gregorianDate is "dd-MM-yyyy".
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  /// Converts "dd-MM-yyyy" (PrayerTimes.date.gregorianDate) to "yyyy-MM-dd".
  String _toIsoDate(String ddMMYyyy) {
    final parts = ddMMYyyy.split('-');
    if (parts.length != 3) return ddMMYyyy;
    final dd = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    final yyyy = parts[2];
    return '$yyyy-$mm-$dd';
  }

  String _prayerNameLocalized(PrayerName p, String locale) {
    if (locale == 'ar') {
      return const {
        PrayerName.fajr: 'الفجر',
        PrayerName.dhuhr: 'الظهر',
        PrayerName.asr: 'العصر',
        PrayerName.maghrib: 'المغرب',
        PrayerName.isha: 'العشاء',
        PrayerName.sunrise: 'الشروق',
      }[p]!;
    }
    return p.name[0].toUpperCase() + p.name.substring(1);
  }

  String _reminderBody(PrayerName p, int minutes, String locale) {
    final name = _prayerNameLocalized(p, locale);
    if (locale == 'ar') {
      return '$name خلال $minutes دقيقة';
    }
    return '$name in $minutes minutes';
  }
}
