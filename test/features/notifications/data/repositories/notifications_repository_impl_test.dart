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
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

class _MockNative extends Mock implements NotificationsNativeDataSource {}

class _MockLegacyScheduler extends Mock implements PrayerNotificationScheduler {}

void main() {
  late _MockNative native;
  late _MockLegacyScheduler scheduler;
  late NotificationsRepositoryImpl repo;

  final state = PrayerStripState(
    cells: const [PrayerCell(label: 'Fajr', timeFormatted: '4:15')],
    nextPrayerIndex: 0,
    hijriDateLabel: '5 Dhul-Hijjah',
    weekdayLabel: '',
    localeCode: 'en',
    isFriday: false,
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
    repo = NotificationsRepositoryImpl(native: native, legacyScheduler: scheduler);
    registerFallbackValue(state);
    registerFallbackValue(pt);
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  group('enableStrip', () {
    test('returns Right(unit) when native call succeeds', () async {
      when(() => native.enableStrip(any())).thenAnswer((_) async {});
      final r = await repo.enableStrip(state);
      expect(r, const Right(unit));
    });

    test('returns Left(PlatformNotSupportedFailure) on PlatformNotImplemented',
        () async {
      when(() => native.enableStrip(any()))
          .thenThrow(const PlatformNotImplementedException('enableStrip'));
      final r = await repo.enableStrip(state);
      expect(r.isLeft(), true);
      r.fold((f) => expect(f, isA<PlatformNotSupportedFailure>()), (_) {});
    });

    test('returns Left(UnknownNotificationFailure) on unknown exception',
        () async {
      when(() => native.enableStrip(any())).thenThrow(Exception('boom'));
      final r = await repo.enableStrip(state);
      r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
    });
  });

  group('scheduleDailyAdhans', () {
    const allEnabled = {
      PrayerName.fajr: true,
      PrayerName.dhuhr: true,
      PrayerName.asr: true,
      PrayerName.maghrib: true,
      PrayerName.isha: true,
    };

    test('Android: routes to native with filtered timings; ignores legacy',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        days: [pt],
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: allEnabled,
        localeCode: 'en',
      );

      expect(r, const Right(unit));
      verify(() => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).called(1);
      verifyNever(() => scheduler.scheduleDailyPrayerNotifications(any()));
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: omits prayers whose enabled=false from the timings map',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Map<String, String>? capturedTimings;
      when(() => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((invocation) async {
        final days = invocation.namedArguments[#days]
            as List<Map<String, dynamic>>;
        capturedTimings = (days.first['timings'] as Map).cast<String, String>();
      });

      await repo.scheduleDailyAdhans(
        days: [pt],
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: const {
          PrayerName.fajr: false,
          PrayerName.dhuhr: true,
          PrayerName.asr: true,
          PrayerName.maghrib: true,
          PrayerName.isha: false,
        },
        localeCode: 'en',
      );

      expect(capturedTimings!.containsKey('fajr'), false);
      expect(capturedTimings!.containsKey('isha'), false);
      expect(capturedTimings!.containsKey('dhuhr'), true);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: passes days list of length 3 with ISO dates', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      PrayerTimes makePt(String gregorian) => PrayerTimes(
            key: gregorian,
            timings: {
              PrayerName.fajr: '04:15',
              PrayerName.sunrise: '05:07',
              PrayerName.dhuhr: '12:52',
              PrayerName.asr: '16:28',
              PrayerName.maghrib: '19:46',
              PrayerName.isha: '21:16',
            },
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

      final day1 = makePt('22-05-2026');
      final day2 = makePt('23-05-2026');
      final day3 = makePt('24-05-2026');

      List<Map<String, dynamic>>? capturedDays;
      when(() => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((invocation) async {
        capturedDays = (invocation.namedArguments[#days]
                as List)
            .cast<Map<String, dynamic>>();
      });

      await repo.scheduleDailyAdhans(
        days: [day1, day2, day3],
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: allEnabled,
        localeCode: 'en',
      );

      expect(capturedDays, isNotNull);
      expect(capturedDays!.length, 3);
      expect(capturedDays![0]['date'], '2026-05-22');
      expect(capturedDays![1]['date'], '2026-05-23');
      expect(capturedDays![2]['date'], '2026-05-24');
      debugDefaultTargetPlatformOverride = null;
    });

    test('iOS: routes to legacy scheduler, ignores native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => scheduler.scheduleDailyPrayerNotifications(any()))
          .thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        days: [pt],
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: allEnabled,
        localeCode: 'en',
      );

      expect(r, const Right(unit));
      verify(() => scheduler.scheduleDailyPrayerNotifications(pt)).called(1);
      verifyNever(() => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          ));
      debugDefaultTargetPlatformOverride = null;
    });

    test('returns Left(UnknownNotificationFailure) when native throws on Android',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            days: any(named: 'days'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).thenThrow(Exception('boom'));

      final r = await repo.scheduleDailyAdhans(
        days: [pt],
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: allEnabled,
        localeCode: 'en',
      );
      r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
      debugDefaultTargetPlatformOverride = null;
    });
  });

  test('cancelAllAdhans iOS: delegates to legacy scheduler', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(() => scheduler.cancelAllPrayerNotifications())
        .thenAnswer((_) async {});
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
    test('Android: routes to native.schedulePrayerReminders with reminder map',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.schedulePrayerReminders(
            days: any(named: 'days'),
            remindersByPrayer: any(named: 'remindersByPrayer'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((_) async {});

      final r = await repo.schedulePrayerReminders(
        days: [pt],
        reminderMinutesByPrayer: const {
          PrayerName.fajr: 15,
          PrayerName.asr: 10,
          PrayerName.maghrib: 0,
        },
        localeCode: 'en',
      );

      expect(r, const Right(unit));
      verify(() => native.schedulePrayerReminders(
            days: any(named: 'days'),
            remindersByPrayer: {'fajr': 15, 'asr': 10},
            localeCode: 'en',
          )).called(1);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: swallows MissingPluginException as Right(unit)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.schedulePrayerReminders(
            days: any(named: 'days'),
            remindersByPrayer: any(named: 'remindersByPrayer'),
            localeCode: any(named: 'localeCode'),
          )).thenThrow(
        const PlatformNotImplementedException('schedulePrayerReminders'),
      );

      final r = await repo.schedulePrayerReminders(
        days: [pt],
        reminderMinutesByPrayer: const {PrayerName.fajr: 15},
        localeCode: 'en',
      );

      // Partial-rollback safety: treat as "feature unavailable", not an error.
      expect(r, const Right(unit));
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: drops entries where minutes == 0', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Map<String, int>? captured;
      when(() => native.schedulePrayerReminders(
            days: any(named: 'days'),
            remindersByPrayer: any(named: 'remindersByPrayer'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#remindersByPrayer]
            as Map<String, int>;
      });

      await repo.schedulePrayerReminders(
        days: [pt],
        reminderMinutesByPrayer: const {
          PrayerName.fajr: 0,
          PrayerName.dhuhr: 10,
          PrayerName.asr: 0,
        },
        localeCode: 'en',
      );

      expect(captured, {'dhuhr': 10});
      debugDefaultTargetPlatformOverride = null;
    });
  });

  test('cancelAllReminders Android: delegates to native', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    when(() => native.cancelAllReminders()).thenAnswer((_) async {});
    final r = await repo.cancelAllReminders();
    expect(r, const Right(unit));
    verify(() => native.cancelAllReminders()).called(1);
    debugDefaultTargetPlatformOverride = null;
  });

  test('cancelAllReminders iOS: delegates to legacyScheduler.cancelAllStaticReminders',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(() => scheduler.cancelAllStaticReminders()).thenAnswer((_) async {});
    final r = await repo.cancelAllReminders();
    expect(r, const Right(unit));
    verifyZeroInteractions(native);
    verify(() => scheduler.cancelAllStaticReminders()).called(1);
    debugDefaultTargetPlatformOverride = null;
  });
}
