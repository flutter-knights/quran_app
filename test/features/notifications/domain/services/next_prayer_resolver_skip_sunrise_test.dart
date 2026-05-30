import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';

void main() {
  final timings = {
    PrayerName.fajr: '05:00',
    PrayerName.sunrise: '06:00',
    PrayerName.dhuhr: '12:00',
    PrayerName.asr: '15:00',
    PrayerName.maghrib: '18:00',
    PrayerName.isha: '19:30',
  };

  test('default: sunrise can be the next prayer', () {
    final now = DateTime(2026, 5, 30, 5, 30); // after fajr, before sunrise
    expect(NextPrayerResolver.resolve(timings: timings, now: now),
        PrayerName.sunrise);
  });

  test('skipSunrise: jumps past sunrise to dhuhr', () {
    final now = DateTime(2026, 5, 30, 5, 30);
    expect(
        NextPrayerResolver.resolve(
            timings: timings, now: now, skipSunrise: true),
        PrayerName.dhuhr);
  });
}
