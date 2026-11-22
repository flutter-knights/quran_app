import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';
import 'package:quran_app/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:quran_app/features/tafsir/domain/usecases/get_ayah_tafsir.dart';
import 'package:quran_app/features/tafsir/presentation/cubit/tafsir_cubit.dart';

class _FakeRepo implements TafsirRepository {
  final pages = <int>[];
  final requests = <(int, int)>[];
  final pending = <Completer<Either<Failure, Tafsir>>>[];
  final tokens = <CancelToken>[];

  @override
  Future<Either<Failure, Tafsir>> getAyahTafsir({
    required int surah,
    required int ayah,
    required int page,
    required CancelToken cancelToken,
  }) {
    pages.add(page);
    tokens.add(cancelToken);
    requests.add((surah, ayah));
    final completer = Completer<Either<Failure, Tafsir>>();
    pending.add(completer);
    return completer.future;
  }
}

class _PageService implements QuranPageService {
  @override
  int getPageForAyah(int surah, int ayah) => surah == 2 && ayah == 255 ? 42 : 1;

  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

Tafsir _tafsir(int surah, int ayah) =>
    Tafsir(surah: surah, ayah: ayah, text: 't$surah:$ayah');

void main() {
  const a = AyahIdentifier(surah: 1, ayah: 1);
  const b = AyahIdentifier(surah: 1, ayah: 2);
  const kursi = AyahIdentifier(surah: 2, ayah: 255);

  late _FakeRepo repo;
  late TafsirCubit cubit;

  setUp(() {
    repo = _FakeRepo();
    cubit = TafsirCubit(
      getAyahTafsir: GetAyahTafsir(repo),
      pageService: _PageService(),
    );
  });

  tearDown(() => cubit.close());

  test('load emits loading then the tafsir', () async {
    final states = <TafsirState>[];
    final sub = cubit.stream.listen(states.add);
    final future = cubit.load(a);
    repo.pending.single.complete(Right(_tafsir(1, 1)));
    await future;
    await pumpEventQueue();
    await sub.cancel();
    expect(states, [const TafsirLoading(a), TafsirLoaded(a, _tafsir(1, 1))]);
  });

  test("asks for the ayah's own page", () async {
    final future = cubit.load(kursi);
    repo.pending.single.complete(Right(_tafsir(2, 255)));
    await future;
    expect(repo.pages, [42]);
    expect(repo.requests, [(2, 255)]);
  });

  test('a failure emits failed for that ayah', () async {
    final future = cubit.load(a);
    repo.pending.single.complete(const Left(NetworkFailure('offline')));
    await future;
    expect(cubit.state, const TafsirFailed(a));
  });

  test('ayah 0 loads nothing', () async {
    await cubit.load(const AyahIdentifier(surah: 2, ayah: 0));
    expect(repo.requests, isEmpty);
    expect(cubit.state, const TafsirIdle());
  });

  test('an ayah already loaded is not fetched again', () async {
    final future = cubit.load(a);
    repo.pending.single.complete(Right(_tafsir(1, 1)));
    await future;
    await cubit.load(a);
    expect(repo.requests, [(1, 1)]);
    expect(cubit.state, TafsirLoaded(a, _tafsir(1, 1)));
  });

  test('a slow first ayah never overwrites a newer one', () async {
    final states = <TafsirState>[];
    final sub = cubit.stream.listen(states.add);
    final first = cubit.load(a);
    final second = cubit.load(b);
    repo.pending[1].complete(Right(_tafsir(1, 2)));
    await second;
    repo.pending[0].complete(Right(_tafsir(1, 1)));
    await first;
    await pumpEventQueue();
    await sub.cancel();
    expect(states.last, TafsirLoaded(b, _tafsir(1, 2)));
    expect(states.whereType<TafsirLoaded>().map((s) => s.ayah), [b]);
  });

  test('retry reloads the failed ayah', () async {
    final failing = cubit.load(a);
    repo.pending[0].complete(const Left(NetworkFailure('offline')));
    await failing;
    final retrying = cubit.retry();
    expect(cubit.state, const TafsirLoading(a));
    repo.pending[1].complete(Right(_tafsir(1, 1)));
    await retrying;
    expect(cubit.state, TafsirLoaded(a, _tafsir(1, 1)));
  });

  test('cancel drops the pending result and never emits failed', () async {
    final states = <TafsirState>[];
    final sub = cubit.stream.listen(states.add);
    final future = cubit.load(a);
    cubit.cancel();
    expect(cubit.state, const TafsirIdle());
    expect(repo.tokens.single.isCancelled, isTrue);
    repo.pending.single.complete(const Left(NetworkFailure('offline')));
    await future;
    await pumpEventQueue();
    await sub.cancel();
    expect(states, [const TafsirLoading(a), const TafsirIdle()]);
  });

  blocTest<TafsirCubit, TafsirState>(
    'cancel after a load keeps the tafsir',
    build: () => cubit,
    seed: () => TafsirLoaded(a, _tafsir(1, 1)),
    act: (c) => c.cancel(),
    expect: () => <TafsirState>[],
    verify: (c) => expect(c.state, TafsirLoaded(a, _tafsir(1, 1))),
  );

  test('close cancels the request in flight', () async {
    final future = cubit.load(a);
    await cubit.close();
    expect(repo.tokens.single.isCancelled, isTrue);
    repo.pending.single.complete(Right(_tafsir(1, 1)));
    await future;
  });

  test('ayat of one page share a token that another page cancels', () async {
    final first = cubit.load(a);
    final second = cubit.load(b);
    expect(repo.tokens[1], same(repo.tokens[0]));
    final third = cubit.load(kursi);
    expect(repo.tokens[0].isCancelled, isTrue);
    expect(repo.tokens[2].isCancelled, isFalse);
    for (final c in repo.pending) {
      c.complete(const Left(NetworkFailure('x')));
    }
    await Future.wait([first, second, third]);
  });

  test('closing one cubit leaves another cubit request alone', () async {
    final other = TafsirCubit(
      getAyahTafsir: GetAyahTafsir(repo),
      pageService: _PageService(),
    );
    final mine = cubit.load(a);
    final theirs = other.load(a);
    await other.close();
    expect(repo.tokens[0].isCancelled, isFalse);
    expect(repo.tokens[1].isCancelled, isTrue);
    repo.pending[0].complete(Right(_tafsir(1, 1)));
    repo.pending[1].complete(Right(_tafsir(1, 1)));
    await mine;
    await theirs;
    expect(cubit.state, TafsirLoaded(a, _tafsir(1, 1)));
  });

  test('retry after a failure reuses the live token', () async {
    final failing = cubit.load(a);
    repo.pending[0].complete(const Left(NetworkFailure('offline')));
    await failing;
    final retrying = cubit.retry();
    expect(repo.tokens[1], same(repo.tokens[0]));
    repo.pending[1].complete(Right(_tafsir(1, 1)));
    await retrying;
  });

  test('cancel after close during a load does not throw', () async {
    final future = cubit.load(a);
    await cubit.close();
    expect(cubit.state, const TafsirLoading(a));
    expect(cubit.cancel, returnsNormally);
    repo.pending.single.complete(Right(_tafsir(1, 1)));
    await future;
  });
}
