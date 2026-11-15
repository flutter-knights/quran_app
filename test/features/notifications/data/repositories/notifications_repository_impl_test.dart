import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class _MockNative extends Mock implements NotificationsNativeDataSource {}

class _MockLegacyScheduler extends Mock
    implements PrayerNotificationScheduler {}

void main() {
  late _MockNative native;
  late _MockLegacyScheduler scheduler;
  late NotificationsRepositoryImpl repo;

  final window = PrayerStripWindow(
    days: [
      const PrayerStripState(
        cells: [
          PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255),
        ],
        nextPrayerIndex: 0,
        dateKey: '22-05-2026',
        hijriDateLabel: '5 Dhul-Hijjah',
        weekdayLabel: '',
        localeCode: 'en',
        isFriday: false,
      ),
    ],
  );

  final pt = PrayerTimes(
    key: '22-05-2026',
    timings: {
      PrayerName.fajr: '04:15',
      PrayerName.sunrise: '05:07',
      PrayerName.dhuhr: '12:52',
      PrayerName.asr: '16:28',
      PrayerName.maghrib: '19:46',
      PrayerName.isha: '21:16',
    },
    date: Date(
      month: 'ذو الحجة',
      weekDay: 'الجمعة',
      day: '5',
      year: '1447',
      enMonth: 'Dhul-Hijjah',
      enWeekDay: 'Friday',
      gregorianDate: '22-05-2026',
    ),
  );

  setUp(() {
    native = _MockNative();
    scheduler = _MockLegacyScheduler();
    repo = NotificationsRepositoryImpl(
      native: native,
      legacyScheduler: scheduler,
    );
    registerFallbackValue(window);
    registerFallbackValue(pt);
    registerFallbackValue(<Map<String, dynamic>>[]);
    registerFallbackValue(<String, Map<String, Object>>{});
    registerFallbackValue(PrayerName.fajr);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Duration.zero);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  void stubAdhans() => when(
    () => native.scheduleDailyAdhans(
      days: any(named: 'days'),
      alerts: any(named: 'alerts'),
      localeCode: any(named: 'localeCode'),
    ),
  ).thenAnswer((_) async {});

  void stubReminders() => when(
    () => native.schedulePrayerReminders(
      days: any(named: 'days'),
      reminders: any(named: 'reminders'),
      localeCode: any(named: 'localeCode'),
    ),
  ).thenAnswer((_) async {});

  group('enableStrip', () {
    test('returns Right(unit) when native call succeeds', () async {
      when(() => native.enableStrip(any())).thenAnswer((_) async {});
      final r = await repo.enableStrip(window);
      expect(r, const Right(unit));
    });

    test(
      'returns Left(PlatformNotSupportedFailure) on PlatformNotImplemented',
      () async {
        when(
          () => native.enableStrip(any()),
        ).thenThrow(const PlatformNotImplementedException('enableStrip'));
        final r = await repo.enableStrip(window);
        expect(r.isLeft(), true);
        r.fold((f) => expect(f, isA<PlatformNotSupportedFailure>()), (_) {});
      },
    );

    test(
      'returns Left(UnknownNotificationFailure) on unknown exception',
      () async {
        when(() => native.enableStrip(any())).thenThrow(Exception('boom'));
        final r = await repo.enableStrip(window);
        r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
      },
    );
  });

  group('scheduleDailyAdhans', () {
    test(
      'Android: sends all six timings and only enabled prayers in alerts',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        stubAdhans();
        final r = await repo.scheduleDailyAdhans(
          days: [pt],
          alerts: {
            ...Settings.defaultPrayerAlerts,
            PrayerName.asr: const PrayerAlert(enabled: false),
            PrayerName.fajr: const PrayerAlert(
              sound: PrayerSound.vibrate,
              ringInSilent: true,
            ),
          },
          localeCode: 'ar',
        );
        expect(r, const Right(unit));
        final captured = verify(
          () => native.scheduleDailyAdhans(
            days: captureAny(named: 'days'),
            alerts: captureAny(named: 'alerts'),
            localeCode: 'ar',
          ),
        ).captured;
        expect(
          (captured[0] as List).single['timings'].keys,
          containsAll(['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']),
        );
        expect((captured[1] as Map).keys, ['fajr', 'dhuhr', 'maghrib', 'isha']);
        expect(captured[1]['fajr'], {'sound': 'vibrate', 'ringInSilent': true});
        expect(captured[1]['dhuhr'], {'sound': 'adhan', 'ringInSilent': false});
        verifyNever(() => scheduler.scheduleDailyPrayerNotifications(any()));
      },
    );

    test(
      'Android: every prayer disabled still sends an empty alerts map',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        stubAdhans();
        await repo.scheduleDailyAdhans(
          days: [pt],
          alerts: {
            for (final p in alertPrayers) p: const PrayerAlert(enabled: false),
          },
          localeCode: 'en',
        );
        final captured = verify(
          () => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            alerts: captureAny(named: 'alerts'),
            localeCode: 'en',
          ),
        ).captured;
        expect(captured.single, isEmpty);
      },
    );

    test('Android: passes days list of length 3 with ISO dates', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      PrayerTimes makePt(String gregorian) => PrayerTimes(
        key: gregorian,
        timings: pt.timings,
        date: Date(
          month: 'test',
          weekDay: 'Monday',
          day: gregorian.split('-')[0],
          year: gregorian.split('-')[2],
          enMonth: 'Test',
          enWeekDay: 'Monday',
          gregorianDate: gregorian,
        ),
      );

      stubAdhans();
      await repo.scheduleDailyAdhans(
        days: [
          makePt('22-05-2026'),
          makePt('23-05-2026'),
          makePt('24-05-2026'),
        ],
        alerts: Settings.defaultPrayerAlerts,
        localeCode: 'en',
      );

      final captured = verify(
        () => native.scheduleDailyAdhans(
          days: captureAny(named: 'days'),
          alerts: any(named: 'alerts'),
          localeCode: 'en',
        ),
      ).captured;
      final days = (captured.single as List).cast<Map<String, dynamic>>();
      expect(days.map((d) => d['date']), [
        '2026-05-22',
        '2026-05-23',
        '2026-05-24',
      ]);
    });

    test('iOS: routes to legacy scheduler, ignores native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(
        () => scheduler.scheduleDailyPrayerNotifications(any()),
      ).thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        days: [pt],
        alerts: Settings.defaultPrayerAlerts,
        localeCode: 'en',
      );

      expect(r, const Right(unit));
      verify(() => scheduler.scheduleDailyPrayerNotifications(pt)).called(1);
      verifyZeroInteractions(native);
    });

    test(
      'returns Left(UnknownNotificationFailure) when native throws on Android',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        when(
          () => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            alerts: any(named: 'alerts'),
            localeCode: any(named: 'localeCode'),
          ),
        ).thenThrow(Exception('boom'));

        final r = await repo.scheduleDailyAdhans(
          days: [pt],
          alerts: Settings.defaultPrayerAlerts,
          localeCode: 'en',
        );
        expect(r.isLeft(), isTrue);
        r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
      },
    );
  });

  test('cancelAllAdhans iOS: delegates to legacy scheduler', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(
      () => scheduler.cancelAllPrayerNotifications(),
    ).thenAnswer((_) async {});
    final r = await repo.cancelAllAdhans();
    expect(r, const Right(unit));
    verify(() => scheduler.cancelAllPrayerNotifications()).called(1);
    debugDefaultTargetPlatformOverride = null;
  });

  test('cancelAllAdhans Android: delegates to native', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    when(() => native.cancelAllAdhans()).thenAnswer((_) async {});
    final r = await repo.cancelAllAdhans();
    expect(r, const Right(unit));
    verify(() => native.cancelAllAdhans()).called(1);
    verifyNever(() => scheduler.cancelAllPrayerNotifications());
    debugDefaultTargetPlatformOverride = null;
  });

  group('schedulePrayerReminders', () {
    test(
      'Android: reminders only for enabled prayers with reminderEnabled',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        stubReminders();
        final r = await repo.schedulePrayerReminders(
          days: [pt],
          alerts: {
            ...Settings.defaultPrayerAlerts,
            PrayerName.fajr: const PrayerAlert(
              reminderEnabled: true,
              reminderMinutes: 15,
              reminderSound: ReminderSound.silent,
            ),
            PrayerName.asr: const PrayerAlert(
              enabled: false,
              reminderEnabled: true,
            ),
          },
          localeCode: 'en',
        );
        expect(r, const Right(unit));
        final captured = verify(
          () => native.schedulePrayerReminders(
            days: captureAny(named: 'days'),
            reminders: captureAny(named: 'reminders'),
            localeCode: 'en',
          ),
        ).captured;
        expect(
          (captured[0] as List).single['timings'].keys,
          containsAll(['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']),
        );
        expect(captured[1], {
          'fajr': {'minutes': 15, 'reminderSound': 'silent'},
        });
      },
    );

    test(
      'Android: swallows PlatformNotImplementedException as Right(unit)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        when(
          () => native.schedulePrayerReminders(
            days: any(named: 'days'),
            reminders: any(named: 'reminders'),
            localeCode: any(named: 'localeCode'),
          ),
        ).thenThrow(
          const PlatformNotImplementedException('schedulePrayerReminders'),
        );

        final r = await repo.schedulePrayerReminders(
          days: [pt],
          alerts: Settings.defaultPrayerAlerts,
          localeCode: 'en',
        );

        // Partial-rollback safety: treat as "feature unavailable", not an error.
        expect(r, const Right(unit));
      },
    );

    test(
      'iOS: schedules static reminders from effectiveReminderMinutes',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        when(
          () => scheduler.cancelAllStaticReminders(),
        ).thenAnswer((_) async {});
        when(
          () => scheduler.scheduleStaticReminder(
            prayer: any(named: 'prayer'),
            at: any(named: 'at'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});

        await repo.schedulePrayerReminders(
          days: [pt],
          alerts: {
            ...Settings.defaultPrayerAlerts,
            PrayerName.maghrib: const PrayerAlert(
              reminderEnabled: true,
              reminderMinutes: 5,
            ),
            PrayerName.isha: const PrayerAlert(
              enabled: false,
              reminderEnabled: true,
            ),
          },
          localeCode: 'en',
        );

        verify(() => scheduler.cancelAllStaticReminders()).called(1);
        verify(
          () => scheduler.scheduleStaticReminder(
            prayer: PrayerName.maghrib,
            at: DateTime(2026, 5, 22, 19, 41),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).called(1);
        verifyNoMoreInteractions(scheduler);
        verifyZeroInteractions(native);
      },
    );
  });

  test('cancelAllReminders Android: delegates to native', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    when(() => native.cancelAllReminders()).thenAnswer((_) async {});
    final r = await repo.cancelAllReminders();
    expect(r, const Right(unit));
    verify(() => native.cancelAllReminders()).called(1);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'cancelAllReminders iOS: delegates to legacyScheduler.cancelAllStaticReminders',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => scheduler.cancelAllStaticReminders()).thenAnswer((_) async {});
      final r = await repo.cancelAllReminders();
      expect(r, const Right(unit));
      verifyZeroInteractions(native);
      verify(() => scheduler.cancelAllStaticReminders()).called(1);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  group('scheduleTestAdhan', () {
    test('scheduleTestAdhan sends Dhuhr sound', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(
        () => native.scheduleTestAdhan(
          delay: any(named: 'delay'),
          localeCode: any(named: 'localeCode'),
          sound: any(named: 'sound'),
          ringInSilent: any(named: 'ringInSilent'),
        ),
      ).thenAnswer((_) async {});
      final r = await repo.scheduleTestAdhan(
        alert: const PrayerAlert(sound: PrayerSound.tone),
        localeCode: 'ar',
      );
      expect(r, const Right(unit));
      verify(
        () => native.scheduleTestAdhan(
          delay: const Duration(seconds: 5),
          localeCode: 'ar',
          sound: 'tone',
          ringInSilent: false,
        ),
      ).called(1);
    });

    test('iOS: delegates to the legacy test notification', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(
        () => scheduler.scheduleTestNotification(delay: any(named: 'delay')),
      ).thenAnswer((_) async {});
      final r = await repo.scheduleTestAdhan(
        alert: const PrayerAlert(),
        localeCode: 'en',
      );
      expect(r, const Right(unit));
      verify(
        () => scheduler.scheduleTestNotification(
          delay: const Duration(seconds: 5),
        ),
      ).called(1);
      verifyZeroInteractions(native);
    });
  });

  group('reliability, settings and preview', () {
    test('Android: getReliabilityStatus maps the native map', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.getReliabilityStatus()).thenAnswer(
        (_) async => {'isXiaomi': true, 'batteryUnrestricted': false},
      );
      final r = await repo.getReliabilityStatus();
      final status = r.getOrElse(() => throw StateError('expected Right'));
      expect(status.isXiaomi, isTrue);
      expect(status.batteryUnrestricted, isFalse);
      expect(status.notificationsEnabled, isTrue);
    });

    test('Android: getReliabilityStatus maps PlatformNotImplemented to '
        'Left(PlatformNotSupportedFailure)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.getReliabilityStatus()).thenThrow(
        const PlatformNotImplementedException('getReliabilityStatus'),
      );
      final r = await repo.getReliabilityStatus();
      r.fold(
        (f) => expect(f, isA<PlatformNotSupportedFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('Android: getReliabilityStatus maps other errors to '
        'Left(UnknownNotificationFailure)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.getReliabilityStatus()).thenThrow(Exception('boom'));
      final r = await repo.getReliabilityStatus();
      r.fold(
        (f) => expect(f, isA<UnknownNotificationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'iOS: getReliabilityStatus is Right with the permission flag',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        when(
          () => scheduler.areNotificationsEnabled(),
        ).thenAnswer((_) async => false);
        final r = await repo.getReliabilityStatus();
        expect(
          r,
          const Right(ReliabilityStatus.ios(notificationsEnabled: false)),
        );
        verifyZeroInteractions(native);
      },
    );

    test('iOS: getReliabilityStatus stays Right when the permission check '
        'throws', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(
        () => scheduler.areNotificationsEnabled(),
      ).thenThrow(Exception('boom'));
      final r = await repo.getReliabilityStatus();
      expect(
        r,
        const Right(ReliabilityStatus.ios(notificationsEnabled: false)),
      );
    });

    test('Android: settings, preview and ack calls reach native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.openSystemSettings(any())).thenAnswer((_) async {});
      when(
        () => native.previewSound(
          sound: any(named: 'sound'),
          prayer: any(named: 'prayer'),
        ),
      ).thenAnswer((_) async {});
      when(() => native.stopPreview()).thenAnswer((_) async {});
      when(() => native.ackMissed()).thenAnswer((_) async {});

      expect(
        await repo.openSystemSettings(SystemSettingsTarget.xiaomiBattery),
        const Right(unit),
      );
      expect(
        await repo.previewSound(
          sound: PreviewSound.adhan,
          prayer: PrayerName.fajr,
        ),
        const Right(unit),
      );
      expect(await repo.stopPreview(), const Right(unit));
      expect(await repo.ackMissedAlerts(), const Right(unit));

      verify(() => native.openSystemSettings('xiaomiBattery')).called(1);
      verify(
        () => native.previewSound(sound: 'adhan', prayer: 'fajr'),
      ).called(1);
      verify(() => native.stopPreview()).called(1);
      verify(() => native.ackMissed()).called(1);
    });

    test('Android: openSystemSettings failure is a Left', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.openSystemSettings(any())).thenThrow(Exception('boom'));
      final r = await repo.openSystemSettings(SystemSettingsTarget.battery);
      expect(r.isLeft(), isTrue);
    });

    test('iOS: openSystemSettings, previewSound, stopPreview, ackMissedAlerts '
        'are Right no-ops', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        await repo.openSystemSettings(SystemSettingsTarget.notifications),
        const Right(unit),
      );
      expect(
        await repo.previewSound(
          sound: PreviewSound.tone,
          prayer: PrayerName.isha,
        ),
        const Right(unit),
      );
      expect(await repo.stopPreview(), const Right(unit));
      expect(await repo.ackMissedAlerts(), const Right(unit));
      verifyZeroInteractions(native);
    });
  });
}
