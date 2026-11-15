import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  PrayerStripState build() => const PrayerStripState(
    cells: [
      PrayerCell(
        label: 'Fajr',
        timeFormatted: '04:15',
        timeFull: '04:15 AM',
        minutes: 255,
        nextLabel: 'Fajr in',
      ),
      PrayerCell(
        label: 'Dhuhr',
        timeFormatted: '12:52',
        timeFull: '12:52 PM',
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

  test('toJson carries nextLabel and timeFull per cell, no accentColor', () {
    final json = build().toJson();
    final cells = (json['cells'] as List).cast<Map>();
    expect(cells[1]['nextLabel'], 'Dhuhr in');
    expect(cells[1]['timeFull'], '12:52 PM');
    expect(json.containsKey('accentColor'), isFalse);
    expect(json.containsKey('nextTag'), isFalse);
  });

  test('fromJson round-trips dateKey, minutes and labels', () {
    final s = PrayerStripState.fromJson(build().toJson());
    expect(s, build());
    expect(s.cells[1].nextLabel, 'Dhuhr in');
    expect(s.cells[1].timeFull, '12:52 PM');
  });

  test('fromJson reads a missing nextLabel as empty and timeFull as time', () {
    final json = build().toJson();
    for (final c in (json['cells'] as List).cast<Map>()) {
      c
        ..remove('nextLabel')
        ..remove('timeFull');
    }
    final s = PrayerStripState.fromJson(json);
    expect(s.cells[0].nextLabel, '');
    expect(s.cells[0].timeFull, '04:15');
  });
}
