import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  PrayerStripState build() => const PrayerStripState(
        cells: [
          PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255),
          PrayerCell(label: 'Dhuhr', timeFormatted: '12:52', minutes: 772),
        ],
        nextPrayerIndex: 1,
        dateKey: '22-05-2026',
        hijriDateLabel: '5 Dhul-Hijjah',
        weekdayLabel: 'Friday',
        localeCode: 'en',
        isFriday: false,
        accentColor: 0xFF2E5244,
      );

  test('toJson includes dateKey and per-cell minutes', () {
    final json = build().toJson();
    expect(json['dateKey'], '22-05-2026');
    final cells = (json['cells'] as List).cast<Map>();
    expect(cells[0]['label'], 'Fajr');
    expect(cells[0]['time'], '04:15');
    expect(cells[0]['minutes'], 255);
    expect(cells[1]['minutes'], 772);
  });

  test('toJson serializes accentColor as #AARRGGBB hex', () {
    expect(build().toJson()['accentColor'], '#FF2E5244');
  });

  test('fromJson round-trips dateKey, minutes and accentColor', () {
    final s = PrayerStripState.fromJson(build().toJson());
    expect(s.dateKey, '22-05-2026');
    expect(s.cells[0].minutes, 255);
    expect(s.cells[1].minutes, 772);
    expect(s.accentColor, 0xFF2E5244);
  });

  test('fromJson tolerates a missing accentColor', () {
    final json = build().toJson()..remove('accentColor');
    expect(PrayerStripState.fromJson(json).accentColor, isNull);
  });
}
