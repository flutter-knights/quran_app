import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';

class _MockRepo extends Mock implements PrayerTimesRepository {}

PrayerTimes _pt(String dateKey) => PrayerTimes(
      key: dateKey,
      timings: const {
        PrayerName.fajr: '04:15',
        PrayerName.sunrise: '05:07',
        PrayerName.dhuhr: '12:52',
        PrayerName.asr: '16:28',
        PrayerName.maghrib: '19:46',
        PrayerName.isha: '21:16',
      },
      date: Date(
        month: 'ذو الحجة', weekDay: 'الجمعة', day: '5', year: '1447',
        enMonth: 'Dhul-Hijjah', enWeekDay: 'Friday', gregorianDate: dateKey,
      ),
    );

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));

  late _MockRepo repo;
  late BuildPrayerStripWindow useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = BuildPrayerStripWindow(prayerTimesRepository: repo);
  });

  test('builds up to N consecutive cached days starting today', () async {
    final now = DateTime(2026, 5, 22, 6, 0);
    when(() => repo.getCachedForDate(any())).thenAnswer((inv) async {
      final d = inv.positionalArguments.first as DateTime;
      final key =
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      return _pt(key);
    });

    final window = await useCase.call(BuildPrayerStripWindowParams(
      localeCode: 'en', use24Hour: true, now: now, days: 3,
    ));

    expect(window, isNotNull);
    expect(window!.days.length, 3);
    expect(window.days[0].dateKey, '22-05-2026');
    expect(window.days[1].dateKey, '23-05-2026');
    expect(window.days[0].cells.length, 5); // sunrise dropped
  });

  test('stops at the first cache gap', () async {
    final now = DateTime(2026, 5, 22, 6, 0);
    when(() => repo.getCachedForDate(any())).thenAnswer((inv) async {
      final d = inv.positionalArguments.first as DateTime;
      if (d.day >= 24) return null; // 24th onward missing
      final key =
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      return _pt(key);
    });

    final window = await useCase.call(BuildPrayerStripWindowParams(
      localeCode: 'en', use24Hour: true, now: now, days: 7,
    ));

    expect(window!.days.length, 2); // 22nd, 23rd
  });

  test('returns null when today is not cached', () async {
    when(() => repo.getCachedForDate(any())).thenAnswer((_) async => null);
    final window = await useCase.call(BuildPrayerStripWindowParams(
      localeCode: 'en', use24Hour: true, now: DateTime(2026, 5, 22), days: 7,
    ));
    expect(window, isNull);
  });
}
