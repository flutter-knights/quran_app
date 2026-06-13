import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';

void main() {
  // Friday May 22 2026.
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
    test('produces 5 cells in Fajr→Isha order (no sunrise)', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'en', isFriday: false, use24Hour: true,
      );
      expect(s.cells.length, 5);
      expect(s.cells[0].label, 'Fajr');
      expect(s.cells[1].label, 'Dhuhr');
      expect(s.cells[2].label, 'Asr');
      expect(s.cells[3].label, 'Maghrib');
      expect(s.cells[4].label, 'Isha');
    });

    test('each cell carries 24h minutes regardless of display format', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'ar', isFriday: false, use24Hour: false,
      );
      expect(s.cells[0].minutes, 255); // 04:15
      expect(s.cells[1].minutes, 772); // 12:52
      expect(s.cells[2].minutes, 988); // 16:28
      expect(s.cells[4].minutes, 1276); // 21:16
    });

    test('dateKey is derived from gregorianDate', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'en', isFriday: false, use24Hour: true,
      );
      expect(s.dateKey, '22-05-2026');
    });

    test('Arabic locale uses Arabic-Indic numerals in display times', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'ar', isFriday: false, use24Hour: true,
      );
      expect(s.cells[0].timeFormatted, '٠٤:١٥');
    });

    test('isFriday=true swaps Dhuhr label to Jumu\'ah / الجمعة (index 1)', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar', isFriday: true, use24Hour: true,
      );
      expect(ar.cells[1].label, 'الجمعة');
      final en = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.dhuhr,
        localeCode: 'en', isFriday: true, use24Hour: true,
      );
      expect(en.cells[1].label, "Jumu'ah");
    });

    test('nextPrayerIndex matches nextPrayer position in 5-prayer order', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.maghrib,
        localeCode: 'en', isFriday: false, use24Hour: true,
      );
      expect(s.nextPrayerIndex, 3); // fajr=0,dhuhr=1,asr=2,maghrib=3
    });

    test('accentColor passes through; defaults to null', () {
      expect(
        PrayerStripStateBuilder.build(
          prayerTimes: pt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: true,
          accentColor: 0xFF2E5244,
        ).accentColor,
        0xFF2E5244,
      );
      expect(
        PrayerStripStateBuilder.build(
          prayerTimes: pt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: true,
        ).accentColor,
        isNull,
      );
    });

    test('hijri + weekday labels honour locale', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'ar', isFriday: true, use24Hour: true,
      );
      expect(ar.hijriDateLabel, '٥ ذو الحجة');
      expect(ar.weekdayLabel, 'الجمعة');
      final en = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'en', isFriday: true, use24Hour: true,
      );
      expect(en.hijriDateLabel, '5 Dhul-Hijjah');
      expect(en.weekdayLabel, 'Friday');
    });

    group('12-hour format (use24Hour=false) — display only', () {
      test('English afternoon uses 12-hour digits, no suffix', () {
        final s = PrayerStripStateBuilder.build(
          prayerTimes: pt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: false,
        );
        expect(s.cells[0].timeFormatted, '04:15'); // Fajr
        expect(s.cells[1].timeFormatted, '12:52'); // Dhuhr (noon boundary)
        expect(s.cells[2].timeFormatted, '04:28'); // Asr 16:28
        expect(s.cells[4].timeFormatted, '09:16'); // Isha 21:16
      });

      test('midnight 00:00 renders as 12:00', () {
        final midnightPt = PrayerTimes(
          key: pt.key,
          timings: {...pt.timings, PrayerName.fajr: '00:00'},
          date: pt.date,
        );
        final s = PrayerStripStateBuilder.build(
          prayerTimes: midnightPt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: false,
        );
        expect(s.cells[0].timeFormatted, '12:00');
        expect(s.cells[0].minutes, 0);
      });
    });
  });
}
