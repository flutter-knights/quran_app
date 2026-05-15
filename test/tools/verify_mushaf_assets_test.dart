// Asserts every (surah, ayah) from the `quran` package appears exactly once
// across all 604 bounds JSONs.
//
//   flutter test test/tools/verify_mushaf_assets_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  test('every (surah, ayah) is covered exactly once', () {
    final seen = <String>{};
    for (var page = 1; page <= 604; page++) {
      final path =
          'assets/mushaf/bounds/page_${page.toString().padLeft(3, '0')}.json';
      final raw = File(path).readAsStringSync();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();
      for (final a in ayahs) {
        final surah = a['surah'] as int;
        final ayah = a['ayah'] as int;
        if (ayah == 0) continue; // basmala entries — not verse-indexed
        final key = '$surah:$ayah';
        expect(seen.contains(key), isFalse,
            reason: 'duplicate $key on page $page');
        seen.add(key);
      }
    }

    final expected = <String>{};
    for (var s = 1; s <= 114; s++) {
      for (var a = 1; a <= quran.getVerseCount(s); a++) {
        expected.add('$s:$a');
      }
    }

    final missing = expected.difference(seen);
    expect(missing, isEmpty, reason: 'missing ayahs: ${missing.take(10)}');
    final extra = seen.difference(expected);
    expect(extra, isEmpty, reason: 'unexpected ayahs: ${extra.take(10)}');
  });
}
