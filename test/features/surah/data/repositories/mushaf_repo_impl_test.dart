import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_model.dart';
import 'package:quran_app/features/surah/data/repositories/mushaf_repo_impl.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

MushafPageModel _entity(int n) => MushafPageModel(
      pageNumber: n,
      ayahs: const ['A'],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
      basmalaIndexes: const [],
    );

class FakeParser {
  int calls = 0;
  bool shouldThrow = false;
  Future<MushafPageModel> parse(int pageNumber) async {
    calls++;
    if (shouldThrow) throw StateError('boom');
    return _entity(pageNumber);
  }
}

void main() {
  late MushafPageCache cache;
  late FakeParser parser;
  late MushafRepositoryImpl repo;

  setUp(() {
    cache = MushafPageCache(capacity: 5);
    parser = FakeParser();
    repo = MushafRepositoryImpl(pageCache: cache, parser: parser.parse);
  });

  test('cache miss: delegates to parser, caches result, returns Right', () async {
    final result = await repo.getPage(7);
    expect(result, isA<Right<Failure, MushafPageEntity>>());
    expect(parser.calls, 1);
    expect(cache.get(7), isNotNull);
  });

  test('cache hit: does not call parser', () async {
    cache.put(7, _entity(7));
    final result = await repo.getPage(7);
    expect(result, isA<Right<Failure, MushafPageEntity>>());
    expect(parser.calls, 0);
  });

  test('parser throw maps to Left(CacheFailure) and does not cache', () async {
    parser.shouldThrow = true;
    final result = await repo.getPage(7);
    expect(result.isLeft(), isTrue);
    result.fold((f) => expect(f, isA<CacheFailure>()), (_) => fail('expected Left'));
    expect(cache.get(7), isNull);
  });
}
