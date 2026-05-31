import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  group('QCF glyph maps are complete', () {
    test('every surah 1..114 resolves to a non-empty glyph name', () {
      for (var s = 1; s <= 114; s++) {
        final name = quran.getQcfSurahName(s); // throws if missing
        expect(name, isNotEmpty, reason: 'surah $s');
      }
    });

    test('every juz 1..30 resolves to a non-empty glyph name', () {
      for (var j = 1; j <= 30; j++) {
        final name = quran.getQcfJuzName(j); // throws if missing
        expect(name, isNotEmpty, reason: 'juz $j');
      }
    });
  });
}
