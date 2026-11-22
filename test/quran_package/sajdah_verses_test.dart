import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

const expected = {
  (7, 206),
  (13, 15),
  (16, 50),
  (17, 109),
  (19, 58),
  (22, 18),
  (22, 77),
  (25, 60),
  (27, 26),
  (32, 15),
  (38, 24),
  (41, 38),
  (53, 62),
  (84, 21),
  (96, 19),
};

void main() {
  test('isSajdahVerse is true at exactly the 15 sajda ayat', () {
    final hits = <(int, int)>{};
    for (var s = 1; s <= 114; s++) {
      for (var a = 1; a <= quran.getVerseCount(s); a++) {
        if (quran.isSajdahVerse(s, a)) hits.add((s, a));
      }
    }
    expect(hits, expected);
  });

  test('the old wrong positions are not sajdas', () {
    for (final (s, a) in [(16, 49), (17, 107), (27, 25), (41, 37)]) {
      expect(quran.isSajdahVerse(s, a), isFalse, reason: '$s:$a');
    }
  });
}
