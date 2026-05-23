import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  final fajr = const PrayerCell(label: 'Fajr', timeFormatted: '4:15');
  final sunrise = const PrayerCell(label: 'Sunrise', timeFormatted: '5:07');

  test('equality holds for identical states', () {
    final a = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 0,
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: 'Monday',
      localeCode: 'en',
      isFriday: false,
    );
    final b = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 0,
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: 'Monday',
      localeCode: 'en',
      isFriday: false,
    );
    expect(a, b);
  });

  test('different nextPrayerIndex breaks equality', () {
    final a = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 0,
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: 'Monday',
      localeCode: 'en',
      isFriday: false,
    );
    final b = a.copyWith(nextPrayerIndex: 1);
    expect(a == b, false);
  });

  test('toJson produces a map with all fields and is deserializable by fromJson', () {
    final s = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 1,
      hijriDateLabel: '5 ذو الحجة',
      weekdayLabel: 'الجمعة',
      localeCode: 'ar',
      isFriday: true,
    );
    final round = PrayerStripState.fromJson(s.toJson());
    expect(round, s);
  });
}
