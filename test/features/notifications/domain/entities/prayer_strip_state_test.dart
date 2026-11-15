import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  PrayerStripState build() => const PrayerStripState(
    cells: [
      PrayerCell(
        label: 'Fajr',
        timeFormatted: '04:15',
        minutes: 255,
        nextLabel: 'Fajr in',
      ),
      PrayerCell(
        label: 'Dhuhr',
        timeFormatted: '12:52',
        minutes: 772,
        nextLabel: 'Dhuhr in',
      ),
    ],
    nextPrayerIndex: 1,
    dateKey: '22-05-2026',
    hijriDateLabel: '5 Dhul-Hijjah',
    weekdayLabel: 'Friday',
    localeCode: 'en',
    isFriday: false,
    nextTag: 'Next',
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

  test('toJson carries nextLabel per cell and nextTag, no accentColor', () {
    final json = build().toJson();
    final cells = (json['cells'] as List).cast<Map>();
    expect(cells[1]['nextLabel'], 'Dhuhr in');
    expect(json['nextTag'], 'Next');
    expect(json.containsKey('accentColor'), isFalse);
  });

  test('fromJson round-trips dateKey, minutes and labels', () {
    final s = PrayerStripState.fromJson(build().toJson());
    expect(s, build());
    expect(s.cells[1].nextLabel, 'Dhuhr in');
    expect(s.nextTag, 'Next');
  });

  test('fromJson reads missing labels as empty', () {
    final json = build().toJson()..remove('nextTag');
    for (final c in (json['cells'] as List).cast<Map>()) {
      c.remove('nextLabel');
    }
    final s = PrayerStripState.fromJson(json);
    expect(s.nextTag, '');
    expect(s.cells[0].nextLabel, '');
  });
}
