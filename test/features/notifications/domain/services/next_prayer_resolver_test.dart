import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';

void main() {
  const timings = {
    PrayerName.fajr: '04:15',
    PrayerName.sunrise: '05:07',
    PrayerName.dhuhr: '12:52',
    PrayerName.asr: '16:28',
    PrayerName.maghrib: '19:46',
    PrayerName.isha: '21:16',
  };

  group('NextPrayerResolver.resolve (5 prayers, sunrise excluded)', () {
    test('before Fajr → Fajr', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 3, 30)),
        PrayerName.fajr,
      );
    });

    test('after Fajr, before Dhuhr → Dhuhr (sunrise is not a target)', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 5, 30)),
        PrayerName.dhuhr,
      );
    });

    test('between Fajr and Sunrise → Dhuhr (the sunrise-exclusion regression case)', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 4, 30)),
        PrayerName.dhuhr,
      );
    });

    test('between Maghrib and Isha → Isha', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 20, 0)),
        PrayerName.isha,
      );
    });

    test('after Isha → Fajr (wraps to tomorrow\'s first)', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 23, 30)),
        PrayerName.fajr,
      );
    });

    test('empty timings → Fajr (sane default)', () {
      expect(
        NextPrayerResolver.resolve(timings: const {}, now: DateTime(2026, 5, 23, 12, 0)),
        PrayerName.fajr,
      );
    });
  });
}
