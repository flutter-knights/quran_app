import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';

class _FakeUseCase extends Mock implements GetMushafPage {}

MushafPageEntity _entity() => MushafPageEntity(
      pageNumber: 5,
      ayahs: const ['x'],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const [AyahIdentifier(surah: 1, ayah: 1)],
      basmalaIndexes: const [],
    );

void main() {
  late MushafPageCache pageCache;
  late MushafSpansCache spansCache;
  late _FakeUseCase useCase;

  setUp(() {
    pageCache = MushafPageCache(capacity: 10);
    spansCache = MushafSpansCache(capacity: 10, pageCache: pageCache);
    useCase = _FakeUseCase();
  });

  group('cold load', () {
    blocTest<MushafCubit, MushafState>(
      'emits [MushafLoading, MushafLoaded] when use case returns Right',
      build: () => MushafCubit(
        useCase: useCase,
        pageCache: pageCache,
        spansCache: spansCache,
      ),
      setUp: () {
        when(() => useCase.call(5)).thenAnswer((_) async => Right(_entity()));
      },
      act: (c) => c.loadPage(
        pageNumber: 5,
        colorScheme: const ColorScheme.light(),
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        builderContext: null,
      ),
      expect: () => [
        isA<MushafLoading>(),
        isA<MushafLoaded>(),
      ],
    );

    blocTest<MushafCubit, MushafState>(
      'emits [MushafLoading, MushafError] when use case returns Left',
      build: () => MushafCubit(
        useCase: useCase,
        pageCache: pageCache,
        spansCache: spansCache,
      ),
      setUp: () {
        when(() => useCase.call(5))
            .thenAnswer((_) async => const Left(CacheFailure('nope')));
      },
      act: (c) => c.loadPage(
        pageNumber: 5,
        colorScheme: const ColorScheme.light(),
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        builderContext: null,
      ),
      expect: () => [
        isA<MushafLoading>(),
        isA<MushafError>().having((s) => s.message, 'message', 'nope'),
      ],
    );
  });

  test('loadPageSync returns true and emits only Loaded on warm caches', () async {
    pageCache.put(5, _entity());
    spansCache.put(5, <InlineSpan>[const TextSpan(text: 'x')]);

    final cubit = MushafCubit(
      useCase: useCase,
      pageCache: pageCache,
      spansCache: spansCache,
    );
    final emitted = <MushafState>[];
    final sub = cubit.stream.listen(emitted.add);

    final hit = cubit.loadPageSync(
      pageNumber: 5,
      colorScheme: const ColorScheme.light(),
      fontSize: 14,
      lineHeight: 28,
      pageWidth: 300,
      builderContext: null,
    );
    await Future<void>.delayed(Duration.zero);

    expect(hit, isTrue);
    expect(emitted, hasLength(1));
    expect(emitted.single, isA<MushafLoaded>());

    await sub.cancel();
    await cubit.close();
  });

  test('does not emit after close (isClosed guard)', () async {
    when(() => useCase.call(5)).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return Right(_entity());
    });
    final cubit = MushafCubit(
      useCase: useCase,
      pageCache: pageCache,
      spansCache: spansCache,
    );
    unawaited(cubit.loadPage(
      pageNumber: 5,
      colorScheme: const ColorScheme.light(),
      fontSize: 14,
      lineHeight: 28,
      pageWidth: 300,
      builderContext: null,
    ));
    await cubit.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(true, isTrue);
  });
}
