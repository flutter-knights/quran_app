import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';

class _MockRepo extends Mock implements QuranPlaybackRepo {}

void main() {
  late _MockRepo repo;
  late StreamController<Either<Failure, double>> controller;

  SurahDownloadState withStatus(String key, SurahDownloadStatus status) =>
      SurahDownloadState(statuses: {key: status});

  setUpAll(() => registerFallbackValue(Reciter.alafasy));

  setUp(() {
    repo = _MockRepo();
    controller = StreamController<Either<Failure, double>>();
    when(
      () => repo.isSurahDownloaded(
        surah: any(named: 'surah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenReturn(false);
    when(
      () => repo.downloadSurah(
        surah: any(named: 'surah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) => controller.stream);
    when(
      () => repo.deleteSurahDownload(
        surah: any(named: 'surah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() {
    unawaited(controller.close());
  });

  SurahDownloadCubit build() => SurahDownloadCubit(repository: repo);

  blocTest<SurahDownloadCubit, SurahDownloadState>(
    'download walks downloading to downloaded',
    build: build,
    act: (cubit) async {
      cubit.download(Reciter.husary, 2);
      controller
        ..add(const Right(.5))
        ..add(const Right(1.0));
      await controller.close();
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      withStatus('husary:2', const SurahDownloading(0)),
      withStatus('husary:2', const SurahDownloading(.5)),
      withStatus('husary:2', const SurahDownloading(1.0)),
      withStatus('husary:2', const SurahDownloaded()),
    ],
  );

  blocTest<SurahDownloadCubit, SurahDownloadState>(
    'a Left ends in failed',
    build: build,
    act: (cubit) async {
      cubit.download(Reciter.husary, 2);
      controller
        ..add(const Right(.2))
        ..add(const Left(UnknownFailure('x')));
      await controller.close();
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      withStatus('husary:2', const SurahDownloading(0)),
      withStatus('husary:2', const SurahDownloading(.2)),
      withStatus('husary:2', const SurahDownloadFailed()),
    ],
  );

  test('download while downloading does not start a second stream', () {
    final cubit = build()
      ..download(Reciter.husary, 2)
      ..download(Reciter.husary, 2);
    verify(
      () => repo.downloadSurah(surah: 2, reciter: Reciter.husary),
    ).called(1);
    return cubit.close();
  });

  test('cancel stops listening and returns to not downloaded', () async {
    final cubit = build()..download(Reciter.husary, 2);
    expect(controller.hasListener, isTrue);
    await cubit.cancel(Reciter.husary, 2);
    expect(controller.hasListener, isFalse);
    expect(cubit.statusOf(Reciter.husary, 2), const SurahNotDownloaded());
    await cubit.close();
  });

  test('statusOf falls back to the stored record', () async {
    when(
      () => repo.isSurahDownloaded(surah: 2, reciter: Reciter.husary),
    ).thenReturn(true);
    final cubit = build();
    expect(cubit.statusOf(Reciter.husary, 2), const SurahDownloaded());
    expect(cubit.state.statuses, isEmpty);
    await cubit.close();
  });

  test('statuses are per reciter', () async {
    final cubit = build()..download(Reciter.husary, 2);
    expect(cubit.statusOf(Reciter.husary, 2), const SurahDownloading(0));
    expect(cubit.statusOf(Reciter.alafasy, 2), const SurahNotDownloaded());
    await cubit.close();
  });

  blocTest<SurahDownloadCubit, SurahDownloadState>(
    'delete returns to not downloaded',
    build: build,
    act: (cubit) => cubit.delete(Reciter.husary, 2),
    expect: () => [withStatus('husary:2', const SurahNotDownloaded())],
    verify: (_) => verify(
      () => repo.deleteSurahDownload(surah: 2, reciter: Reciter.husary),
    ).called(1),
  );

  test('delete while downloading cancels the download first', () async {
    final cubit = build()..download(Reciter.husary, 2);
    controller.add(const Right(.3));
    await Future<void>.delayed(Duration.zero);
    await cubit.delete(Reciter.husary, 2);
    expect(controller.hasListener, isFalse);
    expect(cubit.statusOf(Reciter.husary, 2), const SurahNotDownloaded());
    controller.add(const Right(.6));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.statusOf(Reciter.husary, 2), const SurahNotDownloaded());
    await cubit.close();
  });

  test('each emit carries a new statuses map', () async {
    final cubit = build();
    final states = <SurahDownloadState>[];
    final sub = cubit.stream.listen(states.add);
    cubit.download(Reciter.husary, 2);
    controller.add(const Right(.5));
    await Future<void>.delayed(Duration.zero);
    expect(states, hasLength(2));
    expect(identical(states[0].statuses, states[1].statuses), isFalse);
    await sub.cancel();
    await cubit.close();
  });

  test('close cancels live downloads', () async {
    final cubit = build()..download(Reciter.husary, 2);
    await cubit.close();
    expect(controller.hasListener, isFalse);
  });

  test('retry after failure downloads again', () async {
    final cubit = build()..download(Reciter.husary, 2);
    controller.add(const Left(UnknownFailure('x')));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.statusOf(Reciter.husary, 2), const SurahDownloadFailed());
    when(
      () => repo.downloadSurah(surah: 2, reciter: Reciter.husary),
    ).thenAnswer((_) => StreamController<Either<Failure, double>>().stream);
    cubit.download(Reciter.husary, 2);
    verify(
      () => repo.downloadSurah(surah: 2, reciter: Reciter.husary),
    ).called(2);
    await cubit.close();
  });
}
