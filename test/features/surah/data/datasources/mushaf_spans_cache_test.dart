import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

List<InlineSpan> _spans(String t) => [TextSpan(text: t)];

MushafPageEntity _stubEntity(int n) => MushafPageEntity(
      pageNumber: n,
      ayahs: const [],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
      basmalaIndexes: const [],
    );

void main() {
  late MushafPageCache pageCache;
  late MushafSpansCache spansCache;

  setUp(() {
    pageCache = MushafPageCache(capacity: 3);
    spansCache = MushafSpansCache(capacity: 3, pageCache: pageCache);
  });

  test('put/get round-trips a list by reference', () {
    final s = _spans('a');
    spansCache.put(1, s);
    expect(identical(spansCache.get(1), s), isTrue);
  });

  test('evicts when over its own capacity', () {
    final cache = MushafSpansCache(capacity: 2, pageCache: pageCache);
    cache.put(1, _spans('a'));
    cache.put(2, _spans('b'));
    cache.put(3, _spans('c'));
    expect(cache.get(1), isNull);
    expect(cache.get(2), isNotNull);
    expect(cache.get(3), isNotNull);
  });

  test('removes entry when page cache evicts the matching key', () {
    spansCache.put(1, _spans('a'));
    for (var i = 1; i <= 4; i++) {
      pageCache.put(i, _stubEntity(i));
    }
    expect(spansCache.get(1), isNull);
  });

  test('clear() drops all entries', () {
    spansCache.put(1, _spans('a'));
    spansCache.put(2, _spans('b'));
    spansCache.clear();
    expect(spansCache.get(1), isNull);
    expect(spansCache.get(2), isNull);
  });
}
