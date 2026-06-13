import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';

void main() {
  PrayerStripState day(String dateKey) => PrayerStripState(
        cells: const [PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255)],
        nextPrayerIndex: 0,
        dateKey: dateKey,
        hijriDateLabel: '5 Dhul-Hijjah',
        weekdayLabel: 'Friday',
        localeCode: 'en',
        isFriday: false,
      );

  test('toJson wraps each day under "days"', () {
    final w = PrayerStripWindow(days: [day('22-05-2026'), day('23-05-2026')]);
    final json = w.toJson();
    final days = (json['days'] as List).cast<Map>();
    expect(days.length, 2);
    expect(days[0]['dateKey'], '22-05-2026');
    expect(days[1]['dateKey'], '23-05-2026');
    expect((days[0]['cells'] as List).length, 1);
  });

  test('value equality by days', () {
    expect(
      PrayerStripWindow(days: [day('22-05-2026')]),
      PrayerStripWindow(days: [day('22-05-2026')]),
    );
  });
}
