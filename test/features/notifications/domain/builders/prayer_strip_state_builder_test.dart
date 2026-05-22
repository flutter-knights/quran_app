import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';

void main() {
  // Friday May 22 2026 — used for the isFriday test.
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

  group('PrayerStripStateBuilder.build', () {
    test('produces 6 cells in Fajr→Isha order', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.cells.length, 6);
      expect(s.cells[0].label, 'Fajr');
      expect(s.cells[5].label, 'Isha');
    });

    test('Arabic locale uses Arabic-Indic numerals in times', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'ar',
        isFriday: false,
      );
      expect(s.cells[0].timeFormatted, '٠٤:١٥');
    });

    test('English locale leaves times as ASCII', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.cells[0].timeFormatted, '04:15');
    });

    test('isFriday=true swaps Dhuhr label to Jumu\'ah / الجمعة', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar',
        isFriday: true,
      );
      expect(ar.cells[2].label, 'الجمعة');

      final en = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'en',
        isFriday: true,
      );
      expect(en.cells[2].label, "Jumu'ah");
    });

    test('isFriday=false keeps Dhuhr label as Dhuhr / الظهر', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar',
        isFriday: false,
      );
      expect(ar.cells[2].label, 'الظهر');
    });

    test('nextPrayerIndex matches nextPrayer position in fixed order', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.maghrib,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.nextPrayerIndex, 4);
    });

    test('hijriDateLabel uses Arabic month name for ar locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'ar',
        isFriday: false,
      );
      expect(s.hijriDateLabel, '٥ ذو الحجة');
    });

    test('hijriDateLabel uses English month name for en locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.hijriDateLabel, '5 Dhul-Hijjah');
    });
  });
}
