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
        use24Hour: true,
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
        use24Hour: true,
      );
      expect(s.cells[0].timeFormatted, '٠٤:١٥');
    });

    test('English locale leaves times as ASCII', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
        use24Hour: true,
      );
      expect(s.cells[0].timeFormatted, '04:15');
    });

    test('isFriday=true swaps Dhuhr label to Jumu\'ah / الجمعة', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar',
        isFriday: true,
        use24Hour: true,
      );
      expect(ar.cells[2].label, 'الجمعة');

      final en = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'en',
        isFriday: true,
        use24Hour: true,
      );
      expect(en.cells[2].label, "Jumu'ah");
    });

    test('isFriday=false keeps Dhuhr label as Dhuhr / الظهر', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar',
        isFriday: false,
        use24Hour: true,
      );
      expect(ar.cells[2].label, 'الظهر');
    });

    test('nextPrayerIndex matches nextPrayer position in fixed order', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.maghrib,
        localeCode: 'en',
        isFriday: false,
        use24Hour: true,
      );
      expect(s.nextPrayerIndex, 4);
    });

    test('hijriDateLabel uses Arabic month name for ar locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'ar',
        isFriday: false,
        use24Hour: true,
      );
      expect(s.hijriDateLabel, '٥ ذو الحجة');
    });

    test('hijriDateLabel uses English month name for en locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
        use24Hour: true,
      );
      expect(s.hijriDateLabel, '5 Dhul-Hijjah');
    });

    test('weekdayLabel uses Arabic weekday for ar locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'ar',
        isFriday: true,
        use24Hour: true,
      );
      expect(s.weekdayLabel, 'الجمعة');
    });

    test('weekdayLabel uses English weekday for en locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: true,
        use24Hour: true,
      );
      expect(s.weekdayLabel, 'Friday');
    });

    group('12-hour format (use24Hour=false)', () {
      test('English: morning + afternoon use 12-hour digits, no suffix', () {
        final s = PrayerStripStateBuilder.build(
          prayerTimes: pt,
          nextPrayer: PrayerName.fajr,
          localeCode: 'en',
          isFriday: false,
          use24Hour: false,
        );
        // Fajr 04:15 → 04:15
        expect(s.cells[0].timeFormatted, '04:15');
        // Dhuhr 12:52 → 12:52 (noon-boundary case)
        expect(s.cells[2].timeFormatted, '12:52');
        // Asr 16:28 → 04:28
        expect(s.cells[3].timeFormatted, '04:28');
        // Isha 21:16 → 09:16
        expect(s.cells[5].timeFormatted, '09:16');
      });

      test('Arabic: 12-hour digits in Arabic-Indic, no ص/م suffix', () {
        final s = PrayerStripStateBuilder.build(
          prayerTimes: pt,
          nextPrayer: PrayerName.fajr,
          localeCode: 'ar',
          isFriday: false,
          use24Hour: false,
        );
        expect(s.cells[0].timeFormatted, '٠٤:١٥');
        expect(s.cells[2].timeFormatted, '١٢:٥٢');
        expect(s.cells[5].timeFormatted, '٠٩:١٦');
      });

      test('midnight 00:00 renders as 12:00', () {
        final midnightPt = PrayerTimes(
          key: pt.key,
          timings: {
            ...pt.timings,
            PrayerName.fajr: '00:00',
          },
          date: pt.date,
        );
        final en = PrayerStripStateBuilder.build(
          prayerTimes: midnightPt,
          nextPrayer: PrayerName.fajr,
          localeCode: 'en',
          isFriday: false,
          use24Hour: false,
        );
        expect(en.cells[0].timeFormatted, '12:00');

        final ar = PrayerStripStateBuilder.build(
          prayerTimes: midnightPt,
          nextPrayer: PrayerName.fajr,
          localeCode: 'ar',
          isFriday: false,
          use24Hour: false,
        );
        expect(ar.cells[0].timeFormatted, '١٢:٠٠');
      });

      test('noon 12:00 renders as 12:00', () {
        final noonPt = PrayerTimes(
          key: pt.key,
          timings: {
            ...pt.timings,
            PrayerName.dhuhr: '12:00',
          },
          date: pt.date,
        );
        final s = PrayerStripStateBuilder.build(
          prayerTimes: noonPt,
          nextPrayer: PrayerName.dhuhr,
          localeCode: 'en',
          isFriday: false,
          use24Hour: false,
        );
        expect(s.cells[2].timeFormatted, '12:00');
      });
    });
  });
}
