import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

MushafPageEntity _entity(int n) => MushafPageEntity(
      pageNumber: n,
      ayahs: const [],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
      basmalaIndexes: const [],
    );

void main() {
  test('get returns null for an absent key', () {
    final cache = MushafPageCache(capacity: 3);
    expect(cache.get(1), isNull);
  });

  test('put then get returns the same instance', () {
    final cache = MushafPageCache(capacity: 3);
    final e = _entity(1);
    cache.put(1, e);
    expect(identical(cache.get(1), e), isTrue);
  });

  test('evicts the least recently used when over capacity', () {
    final cache = MushafPageCache(capacity: 2);
    cache.put(1, _entity(1));
    cache.put(2, _entity(2));
    cache.put(3, _entity(3));
    expect(cache.get(1), isNull); // 1 evicted
    expect(cache.get(2), isNotNull);
    expect(cache.get(3), isNotNull);
  });

  test('get marks an entry as most recently used', () {
    final cache = MushafPageCache(capacity: 2);
    cache.put(1, _entity(1));
    cache.put(2, _entity(2));
    cache.get(1); // touch 1
    cache.put(3, _entity(3)); // evicts 2, not 1
    expect(cache.get(1), isNotNull);
    expect(cache.get(2), isNull);
    expect(cache.get(3), isNotNull);
  });

  test('eviction listener fires with the evicted key', () {
    final cache = MushafPageCache(capacity: 1);
    final evicted = <int>[];
    cache.addEvictionListener(evicted.add);
    cache.put(1, _entity(1));
    cache.put(2, _entity(2)); // evicts 1
    expect(evicted, equals([1]));
  });

  test('trimAround keeps only pages within +/- window of pivot', () {
    final cache = MushafPageCache(capacity: 10);
    for (var i = 1; i <= 10; i++) {
      cache.put(i, _entity(i));
    }
    cache.trimAround(pivot: 5, keep: 5); // keep pages 3..7
    for (var i = 1; i <= 10; i++) {
      final inside = (i - 5).abs() <= 2;
      expect(cache.get(i) != null, inside, reason: 'page $i');
    }
  });
}
