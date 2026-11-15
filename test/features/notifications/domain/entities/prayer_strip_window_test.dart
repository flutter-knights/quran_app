import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_render_style.dart';

void main() {
  PrayerStripState day(String dateKey) => PrayerStripState(
    cells: const [
      PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255),
    ],
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

  test('toJson omits style when unset', () {
    expect(
      PrayerStripWindow(
        days: [day('22-05-2026')],
      ).toJson().containsKey('style'),
      isFalse,
    );
  });

  test('toJson carries style', () {
    const style = StripRenderStyle(
      expanded: true,
      countdown: false,
      highlightDay: 0xFF9A3B3B,
      highlightNight: 0xFFE7A3A3,
      pillTextDay: 0xFFFFFFFF,
      pillTextNight: 0xFF121413,
      shape: 'pill',
    );
    final window = PrayerStripWindow(days: [day('22-05-2026')], style: style);
    expect(window.toJson()['style'], isA<Map>());
    expect(window.toJson()['style'], style.toJson());
    expect(window, isNot(PrayerStripWindow(days: [day('22-05-2026')])));
  });
}
