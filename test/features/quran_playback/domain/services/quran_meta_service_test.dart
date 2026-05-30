import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';

void main() {
  final svc = QuranMetaServiceImpl(pageService: QuranPageServiceImpl());

  test('page 1 -> juz 1, hizb 1, rub 1', () {
    final m = svc.getPageMeta(1);
    expect(m.juz, 1);
    expect(m.hizb, 1);
    expect(m.rub, 1);
  });

  test('hizb 1..60, rub 1..4, juz 1..30 for every page', () {
    for (var p = 1; p <= 604; p++) {
      final m = svc.getPageMeta(p);
      expect(m.hizb, inInclusiveRange(1, 60));
      expect(m.rub, inInclusiveRange(1, 4));
      expect(m.juz, inInclusiveRange(1, 30));
    }
  });

  // Data integrity guard over the bundled boundary table:
  test('boundary table is valid (240, monotonic, in-range, anchors)', () {
    final b = QuranMetaServiceImpl.debugRubBoundaries;
    expect(b.length, 240);
    // Index 0 (first quarter): Surah 1, Ayah 1
    expect(b.first, [1, 1]);
    // Index 8 (ninth quarter = Juz 2 start): Surah 2, Ayah 142
    // NOTE: the spec template mistakenly wrote b[1] for this; b[8] is correct
    // because juz boundaries land at multiples of 8 (each juz = 8 quarters).
    expect(b[8], [2, 142]);
    // b[1] should be the second quarter of Juz 1: Surah 2, Ayah 26
    expect(b[1], [2, 26]);

    int absPos(List<int> e) {
      var t = 0;
      for (var s = 1; s < e[0]; s++) {
        t += quran.getVerseCount(s);
      }
      return t + e[1];
    }

    for (var i = 1; i < b.length; i++) {
      expect(
        absPos(b[i]) > absPos(b[i - 1]),
        isTrue,
        reason: 'not increasing at $i',
      );
      expect(
        b[i][1] <= quran.getVerseCount(b[i][0]),
        isTrue,
        reason: 'ayah out of range at $i',
      );
    }
  });

  // Cross-check: hizb derived from the bundled table must agree with juz from
  // the quran package (each hizb spans exactly 2 juz quarters, so
  // juz == ((hizb-1) ~/ 2) + 1 for every page).
  test('hizb/juz consistency for every page', () {
    for (var p = 1; p <= 604; p++) {
      final m = svc.getPageMeta(p);
      expect(
        ((m.hizb - 1) ~/ 2) + 1,
        m.juz,
        reason: 'hizb/juz mismatch at page $p',
      );
    }
  });
}
