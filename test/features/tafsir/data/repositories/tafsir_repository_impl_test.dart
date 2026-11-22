import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/tafsir/data/datasources/local/tafsir_local_data_source.dart';
import 'package:quran_app/features/tafsir/data/datasources/remote/tafsir_remote_data_source.dart';
import 'package:quran_app/features/tafsir/data/models/tafsir_model.dart';
import 'package:quran_app/features/tafsir/data/repositories/tafsir_repository_impl.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';

class _MockRemote extends Mock implements TafsirRemoteDataSource {}

class _MockLocal extends Mock implements TafsirLocalDataSource {}

List<TafsirModel> _surahOne() => [
  for (var a = 1; a <= 7; a++) TafsirModel(surah: 1, ayah: a, text: 't1:$a'),
];

DioException _dio(DioExceptionType type) =>
    DioException(type: type, requestOptions: RequestOptions());

void main() {
  late _MockRemote remote;
  late _MockLocal local;
  late TafsirRepositoryImpl repo;
  late CancelToken token;

  setUpAll(() {
    registerFallbackValue(CancelToken());
    registerFallbackValue(const <Tafsir>[]);
  });

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    repo = TafsirRepositoryImpl(remote: remote, local: local);
    token = CancelToken();
    when(() => local.get(any(), any())).thenReturn(null);
    when(() => local.putAll(any())).thenAnswer((_) async {});
  });

  CancelToken tokenOfPage(int page) =>
      verify(
            () => remote.getPage(
              page,
              cancelToken: captureAny(named: 'cancelToken'),
            ),
          ).captured.single
          as CancelToken;

  test('a cached ayah never touches the network', () async {
    when(() => local.get(2, 255)).thenReturn('cached');

    final result = await repo.getAyahTafsir(
      surah: 2,
      ayah: 255,
      page: 42,
      cancelToken: token,
    );

    expect(result, const Right(Tafsir(surah: 2, ayah: 255, text: 'cached')));
    verifyNever(
      () => remote.getPage(any(), cancelToken: any(named: 'cancelToken')),
    );
  });

  test('a miss fetches the page once and caches all of it', () async {
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => _surahOne());

    final result = await repo.getAyahTafsir(
      surah: 1,
      ayah: 3,
      page: 1,
      cancelToken: token,
    );

    expect(result, const Right(Tafsir(surah: 1, ayah: 3, text: 't1:3')));
    final stored =
        verify(() => local.putAll(captureAny())).captured.single
            as Iterable<Tafsir>;
    expect(stored.length, 7);
  });

  test('two ayat of one page share one request', () async {
    final completer = Completer<List<TafsirModel>>();
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => completer.future);

    final first = repo.getAyahTafsir(
      surah: 1,
      ayah: 2,
      page: 1,
      cancelToken: token,
    );
    final second = repo.getAyahTafsir(
      surah: 1,
      ayah: 4,
      page: 1,
      cancelToken: token,
    );
    completer.complete(_surahOne());

    expect(await first, const Right(Tafsir(surah: 1, ayah: 2, text: 't1:2')));
    expect(await second, const Right(Tafsir(surah: 1, ayah: 4, text: 't1:4')));
    verify(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).called(1);
    verify(() => local.putAll(any())).called(1);
  });

  test(
    'an ayah missing from the page falls back to the ayah endpoint',
    () async {
      when(
        () => remote.getPage(50, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const [TafsirModel(surah: 3, ayah: 8, text: 't3:8')],
      );
      when(
        () => remote.getAyah(3, 9, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const TafsirModel(surah: 3, ayah: 9, text: 't3:9'),
      );

      final result = await repo.getAyahTafsir(
        surah: 3,
        ayah: 9,
        page: 50,
        cancelToken: token,
      );

      expect(result, const Right(Tafsir(surah: 3, ayah: 9, text: 't3:9')));
      final pageToken = tokenOfPage(50);
      expect(pageToken, same(token));
      final ayahToken =
          verify(
                () => remote.getAyah(
                  3,
                  9,
                  cancelToken: captureAny(named: 'cancelToken'),
                ),
              ).captured.single
              as CancelToken;
      expect(ayahToken, same(pageToken));
      final stored = verify(() => local.putAll(captureAny())).captured;
      expect(stored.last, const [Tafsir(surah: 3, ayah: 9, text: 't3:9')]);
    },
  );

  test('a second miss on a fetched page skips the page download', () async {
    when(
      () => remote.getPage(50, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => const [TafsirModel(surah: 3, ayah: 8, text: 't3:8')],
    );
    when(
      () =>
          remote.getAyah(any(), any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (i) async => TafsirModel(
        surah: i.positionalArguments[0] as int,
        ayah: i.positionalArguments[1] as int,
        text: 'x',
      ),
    );

    await repo.getAyahTafsir(surah: 3, ayah: 9, page: 50, cancelToken: token);
    final second = await repo.getAyahTafsir(
      surah: 3,
      ayah: 10,
      page: 50,
      cancelToken: token,
    );

    expect(second.isRight(), isTrue);
    verify(
      () => remote.getPage(50, cancelToken: any(named: 'cancelToken')),
    ).called(1);
    verify(
      () => remote.getAyah(3, 10, cancelToken: any(named: 'cancelToken')),
    ).called(1);
  });

  test('each token fetches its own page and cancels alone', () async {
    final other = CancelToken();
    final first = Completer<List<TafsirModel>>();
    final second = Completer<List<TafsirModel>>();
    var calls = 0;
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => calls++ == 0 ? first.future : second.future);

    final a = repo.getAyahTafsir(
      surah: 1,
      ayah: 1,
      page: 1,
      cancelToken: token,
    );
    final b = repo.getAyahTafsir(
      surah: 1,
      ayah: 2,
      page: 1,
      cancelToken: other,
    );
    token.cancel();
    first.completeError(_dio(DioExceptionType.cancel));
    second.complete(_surahOne());

    expect(await a, isA<Left<Failure, Tafsir>>());
    expect(await b, const Right(Tafsir(surah: 1, ayah: 2, text: 't1:2')));
    expect(other.isCancelled, isFalse);
    verify(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).called(2);
  });

  test('the fallback request uses the caller token', () async {
    final fallback = Completer<TafsirModel>();
    when(
      () => remote.getPage(50, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => const [TafsirModel(surah: 3, ayah: 8, text: 't3:8')],
    );
    when(
      () => remote.getAyah(3, 9, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => fallback.future);

    final a = repo.getAyahTafsir(
      surah: 3,
      ayah: 9,
      page: 50,
      cancelToken: token,
    );
    await pumpEventQueue();
    verify(() => remote.getAyah(3, 9, cancelToken: token)).called(1);
    fallback.complete(const TafsirModel(surah: 3, ayah: 9, text: 't3:9'));
    expect(await a, isA<Right<Failure, Tafsir>>());
  });

  test('offline becomes a NetworkFailure, never a throw', () async {
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenThrow(_dio(DioExceptionType.connectionError));

    final result = await repo.getAyahTafsir(
      surah: 1,
      ayah: 1,
      page: 1,
      cancelToken: token,
    );

    expect(result.swap().toOption().toNullable(), isA<NetworkFailure>());
  });

  test('a timeout becomes a TimeoutFailure', () async {
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenThrow(_dio(DioExceptionType.receiveTimeout));

    final result = await repo.getAyahTafsir(
      surah: 1,
      ayah: 1,
      page: 1,
      cancelToken: token,
    );

    expect(result.swap().toOption().toNullable(), isA<TimeoutFailure>());
  });

  test('a page that failed is asked again on the next request', () async {
    var calls = 0;
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw _dio(DioExceptionType.connectionError);
      return _surahOne();
    });

    final first = await repo.getAyahTafsir(
      surah: 1,
      ayah: 1,
      page: 1,
      cancelToken: token,
    );
    final second = await repo.getAyahTafsir(
      surah: 1,
      ayah: 1,
      page: 1,
      cancelToken: token,
    );

    expect(first.isLeft(), isTrue);
    expect(second, const Right(Tafsir(surah: 1, ayah: 1, text: 't1:1')));
    verify(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).called(2);
  });

  test('a malformed body becomes a Failure', () async {
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenThrow(const FormatException());

    final result = await repo.getAyahTafsir(
      surah: 1,
      ayah: 1,
      page: 1,
      cancelToken: token,
    );

    expect(result.isLeft(), isTrue);
  });

  test('a failed cache read becomes a CacheFailure', () async {
    when(() => local.get(1, 1)).thenThrow(CacheException('read'));

    final result = await repo.getAyahTafsir(
      surah: 1,
      ayah: 1,
      page: 1,
      cancelToken: token,
    );

    expect(result.swap().toOption().toNullable(), isA<CacheFailure>());
  });

  test('a failed cache write still returns the text', () async {
    when(
      () => remote.getPage(1, cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => _surahOne());
    when(() => local.putAll(any())).thenThrow(CacheException('x'));

    final result = await repo.getAyahTafsir(
      surah: 1,
      ayah: 2,
      page: 1,
      cancelToken: token,
    );

    expect(result, const Right(Tafsir(surah: 1, ayah: 2, text: 't1:2')));
  });
}
