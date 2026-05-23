import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';

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
    registerFallbackValue(AdhanAudioSettings.defaults());
  });

  test('delegates to repo.scheduleDailyAdhans with defaults when no audio override',
      () async {
    when(() => repo.scheduleDailyAdhans(
          prayerTimes: any(named: 'prayerTimes'),
          audio: any(named: 'audio'),
          localeCode: any(named: 'localeCode'),
        )).thenAnswer((_) async => const Right(unit));

    final result = await useCase.call(
      SyncDailyAdhansParams(prayerTimes: pt, localeCode: 'en'),
    );

    expect(result.isRight(), true);
    verify(() => repo.scheduleDailyAdhans(
          prayerTimes: pt,
          audio: AdhanAudioSettings.defaults(),
          localeCode: 'en',
        )).called(1);
  });
}
