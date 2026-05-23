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
    test('Android: routes to native.scheduleDailyAdhans, ignores legacy scheduler',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          )).thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
      );

      expect(r, const Right(unit));
      verify(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          )).called(1);
      verifyNever(() => scheduler.scheduleDailyPrayerNotifications(any()));
      debugDefaultTargetPlatformOverride = null;
    });

    test('iOS: routes to legacy scheduler, ignores native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => scheduler.scheduleDailyPrayerNotifications(any()))
          .thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
      );

      expect(r, const Right(unit));
      verify(() => scheduler.scheduleDailyPrayerNotifications(pt)).called(1);
      verifyNever(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          ));
      debugDefaultTargetPlatformOverride = null;
    });

    test('returns Left(UnknownNotificationFailure) when native throws on Android',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          )).thenThrow(Exception('boom'));

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
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
}
