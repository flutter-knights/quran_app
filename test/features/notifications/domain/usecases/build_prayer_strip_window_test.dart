import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';

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
    month: 'ذو الحجة',
    weekDay: 'الجمعة',
    day: '5',
    year: '1447',
    enMonth: 'Dhul-Hijjah',
    enWeekDay: 'Friday',
    gregorianDate: dateKey,
  ),
);

void main() {
  final useCase = BuildPrayerStripWindow();
  final cachedDays = [for (var d = 22; d <= 26; d++) _pt('$d-05-2026')];

  test('builds up to N cached days starting today', () async {
    final window = await useCase.call(
      BuildPrayerStripWindowParams(
        localeCode: 'en',
        use24Hour: true,
        now: DateTime(2026, 5, 22, 6),
        days: 3,
        cachedDays: cachedDays,
      ),
    );

    expect(window!.days.length, 3);
    expect(window.days[0].dateKey, '22-05-2026');
    expect(window.days[1].dateKey, '23-05-2026');
    expect(window.days[0].cells.length, 5);
  });

  test('stops when cachedDays runs out', () async {
    final w = await useCase.call(
      BuildPrayerStripWindowParams(
        localeCode: 'ar',
        use24Hour: true,
        now: DateTime(2026, 5, 22, 9),
        days: 30,
        cachedDays: cachedDays.take(2).toList(),
      ),
    );
    expect(w!.days.length, 2);
  });

  test('empty cachedDays returns null', () async {
    final w = await useCase.call(
      BuildPrayerStripWindowParams(
        localeCode: 'ar',
        use24Hour: true,
        now: DateTime(2026, 5, 22, 9),
        cachedDays: const [],
      ),
    );
    expect(w, isNull);
  });
}
