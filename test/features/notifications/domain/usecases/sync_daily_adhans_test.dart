import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late SyncDailyAdhans useCase;

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
    repo = _MockRepo();
    useCase = SyncDailyAdhans(repository: repo);
    registerFallbackValue(pt);
    registerFallbackValue(<PrayerTimes>[]);
  });

  test(
    'delegates to scheduleDailyAdhans AND schedulePrayerReminders',
    () async {
      when(
        () => repo.scheduleDailyAdhans(
          days: any(named: 'days'),
          alerts: any(named: 'alerts'),
          localeCode: any(named: 'localeCode'),
        ),
      ).thenAnswer((_) async => const Right(unit));
      when(
        () => repo.schedulePrayerReminders(
          days: any(named: 'days'),
          alerts: any(named: 'alerts'),
          localeCode: any(named: 'localeCode'),
        ),
      ).thenAnswer((_) async => const Right(unit));

      final result = await useCase.call(
        SyncDailyAdhansParams(
          days: [pt],
          alerts: Settings.defaultPrayerAlerts,
          localeCode: 'en',
        ),
      );

      expect(result.isRight(), true);
      verify(
        () => repo.scheduleDailyAdhans(
          days: [pt],
          alerts: Settings.defaultPrayerAlerts,
          localeCode: 'en',
        ),
      ).called(1);
      verify(
        () => repo.schedulePrayerReminders(
          days: [pt],
          alerts: Settings.defaultPrayerAlerts,
          localeCode: 'en',
        ),
      ).called(1);
    },
  );

  test(
    'returns Left when scheduleDailyAdhans fails (skips reminders)',
    () async {
      when(
        () => repo.scheduleDailyAdhans(
          days: any(named: 'days'),
          alerts: any(named: 'alerts'),
          localeCode: any(named: 'localeCode'),
        ),
      ).thenAnswer((_) async => const Left(UnknownNotificationFailure('boom')));

      final result = await useCase.call(
        SyncDailyAdhansParams(
          days: [pt],
          alerts: Settings.defaultPrayerAlerts,
          localeCode: 'en',
        ),
      );

      expect(result.isLeft(), true);
      verifyNever(
        () => repo.schedulePrayerReminders(
          days: any(named: 'days'),
          alerts: any(named: 'alerts'),
          localeCode: any(named: 'localeCode'),
        ),
      );
    },
  );
}
