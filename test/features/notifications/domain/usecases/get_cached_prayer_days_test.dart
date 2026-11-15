import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_cached_prayer_days.dart';

class _MockRepo extends Mock implements PrayerTimesRepository {}

PrayerTimes fakePrayerTimes(DateTime d) {
  final key =
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  return PrayerTimes(
    key: key,
    timings: const {
      PrayerName.fajr: '04:15',
      PrayerName.sunrise: '05:07',
      PrayerName.dhuhr: '12:52',
      PrayerName.asr: '16:28',
      PrayerName.maghrib: '19:46',
      PrayerName.isha: '21:16',
    },
    date: Date(
      month: 'جمادى الأولى',
      weekDay: 'الأحد',
      day: '1',
      year: '1448',
      enMonth: 'Jumada al-Ula',
      enWeekDay: 'Sunday',
      gregorianDate: key,
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));

  late _MockRepo repo;
  late GetCachedPrayerDays usecase;

  setUp(() {
    repo = _MockRepo();
    usecase = GetCachedPrayerDays(prayerTimesRepository: repo);
  });

  test(
    'GetCachedPrayerDays stops at the first gap and caps at maxDays',
    () async {
      when(() => repo.getCachedForDate(any())).thenAnswer((i) async {
        final d = i.positionalArguments.first as DateTime;
        return d.day == 18 ? null : fakePrayerTimes(d);
      });
      final days = await usecase(
        GetCachedPrayerDaysParams(now: DateTime(2026, 11, 15, 9)),
      );
      expect(days.length, 3);
      final capped = await usecase(
        GetCachedPrayerDaysParams(now: DateTime(2026, 11, 19), maxDays: 5),
      );
      expect(capped.length, 5);
    },
  );

  test('reads midnight dates from today on, across a month end', () async {
    when(() => repo.getCachedForDate(any())).thenAnswer(
      (i) async => fakePrayerTimes(i.positionalArguments.first as DateTime),
    );
    final days = await usecase(
      GetCachedPrayerDaysParams(
        now: DateTime(2026, 11, 29, 23, 50),
        maxDays: 3,
      ),
    );
    expect(days.map((d) => d.key), ['29-11-2026', '30-11-2026', '01-12-2026']);
    verify(() => repo.getCachedForDate(DateTime(2026, 11, 29))).called(1);
  });

  test('returns an empty list when today is not cached', () async {
    when(() => repo.getCachedForDate(any())).thenAnswer((_) async => null);
    final days = await usecase(
      GetCachedPrayerDaysParams(now: DateTime(2026, 11, 15)),
    );
    expect(days, isEmpty);
    verify(() => repo.getCachedForDate(any())).called(1);
  });
}
