import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_local_data_source.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/data/models/reliability_status_model.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsNativeDataSource native;
  final PrayerNotificationScheduler legacyScheduler;
  final NotificationsLocalDataSource local;
  final DateTime Function() clock;
  final Future<bool> Function() openAppSettings;

  NotificationsRepositoryImpl({
    required this.native,
    required this.legacyScheduler,
    required this.local,
    this.clock = DateTime.now,
    this.openAppSettings = Geolocator.openAppSettings,
  });

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<Either<Failure, T>> _runValue<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } on PlatformNotImplementedException {
      return const Left(
        PlatformNotSupportedFailure('Not supported on this platform.'),
      );
    } catch (e) {
      return Left(UnknownNotificationFailure(e.toString()));
    }
  }

  Future<Either<Failure, Unit>> _run(Future<void> Function() body) =>
      _runValue(() async {
        await body();
        return unit;
      });

  Future<Either<Failure, Unit>> _runAndroidOnly(
    Future<void> Function() body,
  ) async {
    if (!_isAndroid) return const Right(unit);
    return _run(body);
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
  Future<Either<Failure, Unit>> enableStrip(PrayerStripWindow window) =>
      _runAndroidOnly(() => native.enableStrip(window));

  @override
  Future<Either<Failure, Unit>> disableStrip() =>
      _runAndroidOnly(native.disableStrip);

  @override
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripWindow window) =>
      _run(() => native.refreshStrip(window));

  @override
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required List<PrayerTimes> days,
    required Map<PrayerName, PrayerAlert> alerts,
    required String localeCode,
  }) => _run(() async {
    if (days.isEmpty) return;
    if (_isAndroid) {
      await native.scheduleDailyAdhans(
        days: _daysPayload(days),
        alerts: {
          for (final p in alertPrayers)
            if (alerts[p] case final a? when a.enabled)
              p.name: {'sound': a.sound.name, 'ringInSilent': a.ringInSilent},
        },
        localeCode: localeCode,
      );
    } else {
      final until = await legacyScheduler.scheduleAlerts(
        days: days,
        alerts: alerts,
        localeCode: localeCode,
      );
      final anyEnabled = alertPrayers.any((p) => alerts[p]?.enabled ?? false);
      await local.writeIosScheduledUntil(anyEnabled ? until ?? clock() : null);
    }
  });

  @override
  Future<Either<Failure, Unit>> cancelAllAdhans() => _run(() async {
    if (_isAndroid) {
      await native.cancelAllAdhans();
    } else {
      await legacyScheduler.cancelAll();
      await local.writeIosScheduledUntil(null);
    }
  });

  @override
  Future<Either<Failure, Unit>> schedulePrayerReminders({
    required List<PrayerTimes> days,
    required Map<PrayerName, PrayerAlert> alerts,
    required String localeCode,
  }) => _runOptional('schedulePrayerReminders', () async {
    if (days.isEmpty || !_isAndroid) return;
    await native.schedulePrayerReminders(
      days: _daysPayload(days),
      reminders: {
        for (final p in alertPrayers)
          if (alerts[p] case final a?)
            if (a.effectiveReminderMinutes case final minutes?)
              p.name: {
                'minutes': minutes,
                'reminderSound': a.reminderSound.name,
              },
      },
      localeCode: localeCode,
    );
  });

  @override
  Future<Either<Failure, Unit>> cancelAllReminders() =>
      _runOptional('cancelAllReminders', () async {
        if (_isAndroid) await native.cancelAllReminders();
      });

  @override
  Future<Either<Failure, Unit>> scheduleTestAdhan({
    required PrayerAlert alert,
    required String localeCode,
    Duration delay = const Duration(seconds: 5),
  }) => _run(() async {
    if (_isAndroid) {
      await native.scheduleTestAdhan(
        delay: delay,
        localeCode: localeCode,
        sound: alert.sound.name,
        ringInSilent: alert.ringInSilent,
      );
    } else {
      await legacyScheduler.scheduleTestNotification(
        alert: alert,
        localeCode: localeCode,
        delay: delay,
      );
    }
  });

  @override
  Future<Either<Failure, ReliabilityStatus>> getReliabilityStatus() =>
      _runValue(() async {
        if (_isAndroid) {
          return ReliabilityStatusModel.fromMap(
            await native.getReliabilityStatus(),
          );
        }
        return ReliabilityStatus.ios(
          notificationsEnabled: await _iosNotificationsEnabled(),
          scheduledUntil: _iosScheduledUntil(),
        );
      });

  DateTime? _iosScheduledUntil() {
    try {
      return local.readIosScheduledUntil();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _iosNotificationsEnabled() async {
    try {
      return await legacyScheduler.areNotificationsEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Either<Failure, Unit>> ackMissedAlerts({required DateTime upTo}) =>
      _runAndroidOnly(
        () => native.ackMissed(upTo: upTo.millisecondsSinceEpoch),
      );

  @override
  Future<Either<Failure, Unit>> openSystemSettings(
    SystemSettingsTarget target,
  ) {
    if (!_isAndroid && target == SystemSettingsTarget.notifications) {
      return _run(openAppSettings);
    }
    return _runAndroidOnly(() => native.openSystemSettings(target.name));
  }

  @override
  Future<Either<Failure, Unit>> previewSound({
    required PreviewSound sound,
    required PrayerName prayer,
  }) => _runAndroidOnly(
    () => native.previewSound(sound: sound.name, prayer: prayer.name),
  );

  @override
  Future<Either<Failure, Unit>> stopPreview() =>
      _runAndroidOnly(native.stopPreview);

  @override
  Future<Either<Failure, int?>> androidSdkInt() async {
    if (!_isAndroid) return const Right(null);
    return _runValue(native.sdkInt);
  }

  @override
  Stream<PreviewSound> previewEnded() {
    if (!_isAndroid) return const Stream.empty();
    final byName = PreviewSound.values.asNameMap();
    return native.previewEnded.expand((name) => [?byName[name]]);
  }

  List<Map<String, dynamic>> _daysPayload(List<PrayerTimes> days) => [
    for (final pt in days)
      {
        'date': _toIsoDate(pt.date.gregorianDate),
        'timings': {
          for (final e in pt.timings.entries) e.key.name.toLowerCase(): e.value,
        },
      },
  ];

  /// Converts "dd-MM-yyyy" (PrayerTimes.date.gregorianDate) to "yyyy-MM-dd".
  String _toIsoDate(String ddMMYyyy) {
    final parts = ddMMYyyy.split('-');
    if (parts.length != 3) return ddMMYyyy;
    final dd = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    final yyyy = parts[2];
    return '$yyyy-$mm-$dd';
  }
}
