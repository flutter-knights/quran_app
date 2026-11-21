import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/services/playback_range_validator.dart';

void main() {
  group('clampFrom (rule 1) — surah 2 has 286 ayahs', () {
    test('0 or below snaps to 1', () {
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: 0), 1);
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: -5), 1);
    });
    test('above verse count clamps to last ayah', () {
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: 999), 286);
    });
    test('in-range passes through', () {
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: 50), 50);
    });
  });

  group('clampTo (rules 2 & 3)', () {
    test('to below from auto-follows from (to=from)', () {
      expect(PlaybackRangeValidator.clampTo(surah: 2, from: 50, value: 10), 50);
    });
    test('to above verse count clamps to last ayah', () {
      expect(PlaybackRangeValidator.clampTo(surah: 2, from: 50, value: 999), 286);
    });
    test('valid to passes through', () {
      expect(PlaybackRangeValidator.clampTo(surah: 2, from: 50, value: 100), 100);
    });
    test('out-of-range from (300) is capped at last (286), result clamps to 286', () {
      expect(PlaybackRangeValidator.clampTo(surah: 2, from: 300, value: 200), 286);
    });
  });

  group('clampRepeat (rule 5)', () {
    test('blank/0 -> 1, negative -> 1', () {
      expect(PlaybackRangeValidator.clampRepeat(0), 1);
      expect(PlaybackRangeValidator.clampRepeat(-3), 1);
    });
    test('caps at 99', () {
      expect(PlaybackRangeValidator.clampRepeat(500), 99);
    });
    test('in-range passes through', () {
      expect(PlaybackRangeValidator.clampRepeat(7), 7);
    });
  });

  group('parseCounter (rule 8) — non-numeric/blank handling', () {
    test('non-numeric returns null (caller keeps last valid)', () {
      expect(PlaybackRangeValidator.parseCounter('abc'), isNull);
      expect(PlaybackRangeValidator.parseCounter(''), isNull);
    });
    test('numeric (incl. Arabic-Indic digits) parses', () {
      expect(PlaybackRangeValidator.parseCounter('12'), 12);
      expect(PlaybackRangeValidator.parseCounter('٧'), 7);
    });
    test('extended Arabic-Indic digit (U+06F7) parses to 7', () {
      expect(PlaybackRangeValidator.parseCounter('۷'), 7);
    });
  });
}
