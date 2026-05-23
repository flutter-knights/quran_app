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

  group('NextPrayerResolver.resolve', () {
    test('before Fajr → Fajr', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 3, 30),
      );
      expect(r, PrayerName.fajr);
    });

    test('between Sunrise and Dhuhr → Dhuhr', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 8, 0),
      );
      expect(r, PrayerName.dhuhr);
    });

    test('between Maghrib and Isha → Isha', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 20, 0),
      );
      expect(r, PrayerName.isha);
    });

    test('after Isha → Fajr (wraps to tomorrow\'s first)', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 23, 30),
      );
      expect(r, PrayerName.fajr);
    });

    test('empty / missing timings → Fajr (sane default)', () {
      final r = NextPrayerResolver.resolve(
        timings: const {},
        now: DateTime(2026, 5, 23, 12, 0),
      );
      expect(r, PrayerName.fajr);
    });
  });
}
