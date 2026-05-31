import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/utils/printed_chrome_resolver.dart';

void main() {
  group('resolvePrintedChrome', () {
    test('page 1 (Al-Fatiha) → surah 1, juz 1', () {
      final d = resolvePrintedChrome(1);
      expect(d.surahNumber, 1);
      expect(d.juzNumber, 1);
      expect(d.surahGlyphName, isNotEmpty);
      expect(d.juzGlyphName, isNotEmpty);
    });

    test('page 2 (Al-Baqarah start) → surah 2, juz 1', () {
      final d = resolvePrintedChrome(2);
      expect(d.surahNumber, 2);
      expect(d.juzNumber, 1);
    });

    test('produces values for every page 1..604 without throwing', () {
      for (var p = 1; p <= 604; p++) {
        final d = resolvePrintedChrome(p);
        expect(d.surahNumber, inInclusiveRange(1, 114));
        expect(d.juzNumber, inInclusiveRange(1, 30));
        expect(d.surahGlyphName, isNotEmpty);
      }
    });
  });
}
