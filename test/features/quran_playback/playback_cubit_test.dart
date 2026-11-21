import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class _MockRepo extends Mock implements QuranPlaybackRepo {}

class _MockSeq extends Mock implements AyahSequenceService {}

class _MockPage extends Mock implements QuranPageService {}

class _FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettings(super.initial);
  double? speedUpdate;
  Reciter? reciterUpdate;
  @override
  void updatePlaybackSpeed(double s) => speedUpdate = s;
  @override
  void updateDefaultReciter(Reciter r) => reciterUpdate = r;
  // unused overrides
  @override
  void updateSettings({bool? isFormat12Hours, bool? isArabic}) {}
  @override
  void updatePalette(ColorPalette palette) {}
  @override
  SettingsState? fromJson(Map<String, dynamic> json) => null;
  @override
  Map<String, dynamic>? toJson(SettingsState state) => null;
  // HydratedMixin members not needed in tests
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _MockRepo repo;
  late _MockSeq seq;
  late _MockPage page;
  late _FakeSettings settings;

  const ayah25 = AyahIdentifier(surah: 2, ayah: 5);

  setUpAll(() {
    registerFallbackValue(ayah25);
    registerFallbackValue(Reciter.alafasy);
    registerFallbackValue(<AyahIdentifier>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);
    void noopCallback() {}
    registerFallbackValue(noopCallback);
  });

  setUp(() {
    repo = _MockRepo();
    seq = _MockSeq();
    page = _MockPage();
    settings = _FakeSettings(
      SettingsState(
        SettingsModel(
          isFormat12Hours: true,
          isArabic: true,
          playbackSpeed: 1.25,
          defaultReciter: Reciter.husary,
        ),
      ),
    );
    when(() => repo.currentAyahStream).thenAnswer((_) => const Stream.empty());
    when(() => repo.onAudioCompleted).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.preloadAyahs(
        ayahs: any(named: 'ayahs'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.setSpeed(any())).thenAnswer((_) async {});
    when(() => repo.stop()).thenAnswer((_) async {});
  });

  PlaybackCubit build() => PlaybackCubit(
    ayahSequenceService: seq,
    repository: repo,
    pageService: page,
    settingsCubit: settings,
  );

  test('seeds state from SettingsCubit', () {
    final c = build();
    expect(c.state.speed, 1.25);
    expect(c.state.reciter, Reciter.husary);
  });

  blocTest<PlaybackCubit, PlaybackState>(
    'pause sets isPaused=true and isPlaying=false',
    build: () {
      when(() => repo.pause()).thenAnswer((_) async {});
      return build()..emit(const PlaybackState(isPlaying: true));
    },
    act: (c) => c.pause(),
    expect: () => [
      isA<PlaybackState>()
          .having((s) => s.isPlaying, 'isPlaying', false)
          .having((s) => s.isPaused, 'isPaused', true),
    ],
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'race guard: playSelected(A) then playSelected(B) before A resolves '
    'notifies only B',
    build: () {
      final completerA = Completer<Either<Failure, String>>();
      var call = 0;
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) {
        call++;
        if (call == 1) return completerA.future;
        return Future.value(const Right('/path/B.mp3'));
      });
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) async {
      // Fire A; do not await — completerA never completes so awaiting would hang
      unawaited(c.playSelected(const AyahIdentifier(surah: 2, ayah: 1)));
      // Fire B and await — it completes and supersedes A's play generation
      await c.playSelected(const AyahIdentifier(surah: 2, ayah: 2));
    },
    verify: (_) {
      verify(
        () => repo.notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 2)),
      ).called(1);
      verifyNever(
        () => repo.notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 1)),
      );
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected applies the cubit speed via repo.setSpeed',
    build: () {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) async => const Right('/p.mp3'));
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(ayah25),
    verify: (_) => verify(() => repo.setSpeed(1.25)).called(1),
  );

  const ayah26 = AyahIdentifier(surah: 2, ayah: 6);

  void stubPlay() {
    when(
      () => repo.playPreparedAudio(any()),
    ).thenAnswer((_) async => const Right(null));
    when(() => repo.notifyAyahChanged(any())).thenReturn(null);
  }

  void stubPrepareFails() {
    when(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
  }

  test(
    'playSelected emits requestedAyah and isLoading synchronously',
    () async {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) => Completer<Either<Failure, String>>().future);
      final c = build();
      unawaited(c.playSelected(ayah25));
      expect(c.state.requestedAyah, ayah25);
      expect(c.state.isLoading, isTrue);
      await c.close();
    },
  );

  test('first play fails offline', () async {
    stubPrepareFails();
    final c = build();
    await c.playSelected(ayah25);
    expect(c.state.requestedAyah, ayah25);
    expect(c.state.currentAyah, isNull);
    expect(c.state.error, isNotNull);
    expect(c.state.isLoading, isFalse);
    verifyNever(() => repo.notifyAyahChanged(any()));
    await c.close();
  });

  group('a failed replacing play', () {
    late StreamController<AyahIdentifier> ayahs;
    late StreamController<void> done;
    late List<PlaybackState> states;

    setUp(() {
      ayahs = StreamController.broadcast();
      done = StreamController.broadcast();
      states = [];
      when(() => repo.currentAyahStream).thenAnswer((_) => ayahs.stream);
      when(() => repo.onAudioCompleted).thenAnswer((_) => done.stream);
      when(() => repo.pause()).thenAnswer((_) async {});
      when(() => repo.resume()).thenAnswer((_) async {});
      when(() => repo.notifyAyahChanged(any())).thenAnswer(
        (i) => ayahs.add(i.positionalArguments.first as AyahIdentifier),
      );
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => seq.getNextAyahs(
          current: any(named: 'current'),
          count: any(named: 'count'),
          endSurah: any(named: 'endSurah'),
          endAyah: any(named: 'endAyah'),
        ),
      ).thenReturn([]);
      when(
        () => seq.getNextAyah(
          current: any(named: 'current'),
          endSurah: any(named: 'endSurah'),
          endAyah: any(named: 'endAyah'),
        ),
      ).thenReturn(ayah26);
      var calls = 0;
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer(
        (i) async => i.namedArguments[#ayah] == ayah26 && ++calls == 1
            ? const Left(NetworkFailure('offline'))
            : const Right('/p.mp3'),
      );
    });

    tearDown(() async {
      await ayahs.close();
      await done.close();
    });

    Future<PlaybackCubit> failedReplace() async {
      final c = build();
      c.stream.listen(states.add);
      await c.playSelected(ayah25);
      await Future<void>.delayed(Duration.zero);
      await c.playSelected(ayah26);
      return c;
    }

    bool playingWithError(PlaybackState s) => s.isPlaying && s.error != null;

    test('stops the old audio and keeps the error', () async {
      final c = await failedReplace();
      verify(() => repo.stop()).called(1);
      expect(c.state.error, isNotNull);
      expect(c.state.isPlaying, isFalse);
      expect(c.state.requestedAyah, ayah26);
      await c.close();
    });

    test('a later success never plays beside the error', () async {
      final c = await failedReplace();
      done.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.isPlaying, isTrue);
      expect(c.state.error, isNull);
      expect(states.where(playingWithError), isEmpty);
      await c.close();
    });

    test('resume retries the requested ayah instead of playing', () async {
      final c = await failedReplace();
      await c.pause();
      await c.resume();
      verify(() => repo.notifyAyahChanged(ayah26)).called(1);
      expect(c.state.error, isNull);
      expect(states.where(playingWithError), isEmpty);
      await c.close();
    });

    test('restartCurrent retries the requested ayah', () async {
      final c = await failedReplace();
      await c.restartCurrent();
      verify(() => repo.notifyAyahChanged(ayah26)).called(1);
      expect(c.state.error, isNull);
      expect(states.where(playingWithError), isEmpty);
      await c.close();
    });

    test('skipNext steps from the requested ayah', () async {
      final c = await failedReplace();
      const ayah27 = AyahIdentifier(surah: 2, ayah: 7);
      when(() => seq.getNextAyah(current: ayah26)).thenReturn(ayah27);
      await c.skipNext();
      verify(() => repo.notifyAyahChanged(ayah27)).called(1);
      await c.close();
    });

    test('skipPrevious steps from the requested ayah', () async {
      final c = await failedReplace();
      when(() => seq.getPreviousAyah(current: ayah26)).thenReturn(ayah25);
      await c.skipPrevious();
      verify(() => repo.notifyAyahChanged(ayah25)).called(2);
      await c.close();
    });
  });

  test('a playSelected during stop keeps its requestedAyah', () async {
    final stopping = Completer<void>();
    when(() => repo.stop()).thenAnswer((_) => stopping.future);
    when(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) => Completer<Either<Failure, String>>().future);
    final c = build();
    final stop = c.stop();
    unawaited(c.playSelected(ayah25));
    stopping.complete();
    await stop;
    expect(c.state.requestedAyah, ayah25);
    expect(c.state.isAutoPlaying, isTrue);
    expect(c.state.isLoading, isTrue);
    await c.close();
  });

  test('error survives an unrelated emit', () async {
    stubPrepareFails();
    final c = build();
    await c.playSelected(ayah25);
    c.setEachAyahRepeat(2);
    expect(c.state.error, isNotNull);
    await c.close();
  });

  test('retry clears error and replays requestedAyah', () async {
    var call = 0;
    when(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer(
      (_) async => ++call == 1
          ? const Left(NetworkFailure('offline'))
          : const Right('/p.mp3'),
    );
    stubPlay();
    final c = build();
    await c.playSelected(ayah25);
    await c.retry();
    verify(() => repo.notifyAyahChanged(ayah25)).called(1);
    expect(c.state.error, isNull);
    await c.close();
  });

  test('retry without a requested ayah does nothing', () async {
    final c = build();
    await c.retry();
    verifyNever(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    );
    await c.close();
  });

  test('playPreparedAudio Left feeds error', () async {
    when(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) async => const Right('/p.mp3'));
    when(() => repo.notifyAyahChanged(any())).thenReturn(null);
    when(
      () => repo.playPreparedAudio(any()),
    ).thenAnswer((_) async => const Left(UnknownFailure('boom')));
    final c = build();
    await c.playSelected(ayah25);
    expect(c.state.error, 'boom');
    expect(c.state.isPlaying, isFalse);
    expect(c.state.isLoading, isFalse);
    await c.close();
  });

  test('playPreparedAudioSequence Left feeds error', () async {
    when(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) async => const Right('/p.mp3'));
    when(
      () => repo.playPreparedAudioSequence(
        any(),
        onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
      ),
    ).thenAnswer((_) async => const Left(UnknownFailure('boom')));
    final c = build();
    await c.playSelected(const AyahIdentifier(surah: 2, ayah: 1));
    expect(c.state.error, 'boom');
    expect(c.state.isPlaying, isFalse);
    expect(c.state.isPlayingBasmala, isFalse);
    await c.close();
  });

  test('stop clears requestedAyah and error', () async {
    stubPrepareFails();
    when(() => repo.stop()).thenAnswer((_) async {});
    final c = build();
    await c.playSelected(ayah25);
    await c.stop();
    expect(c.state.requestedAyah, isNull);
    expect(c.state.error, isNull);
    await c.close();
  });

  test('skipNext clears a stale error', () async {
    when(
      () => seq.getNextAyah(current: any(named: 'current')),
    ).thenReturn(ayah26);
    when(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) async => const Right('/p.mp3'));
    stubPlay();
    final c = build()
      ..emit(const PlaybackState(currentAyah: ayah25, error: 'x'));
    await c.skipNext();
    expect(c.state.error, isNull);
    await c.close();
  });

  void stubPrepareOk() {
    when(
      () => repo.prepareAyahAudio(
        ayah: any(named: 'ayah'),
        reciter: any(named: 'reciter'),
      ),
    ).thenAnswer((_) async => const Right('/p.mp3'));
  }

  test('skipPrevious clears a stale error', () async {
    when(
      () => seq.getPreviousAyah(current: any(named: 'current')),
    ).thenReturn(const AyahIdentifier(surah: 2, ayah: 4));
    stubPrepareOk();
    stubPlay();
    final c = build()
      ..emit(const PlaybackState(currentAyah: ayah25, error: 'x'));
    await c.skipPrevious();
    expect(c.state.error, isNull);
    await c.close();
  });

  test(
    'playRange emits requestedAyah (normalised from ayah 0) and clears error',
    () async {
      stubPrepareOk();
      stubPlay();
      final c = build()..emit(const PlaybackState(error: 'x'));
      final states = <PlaybackState>[];
      final sub = c.stream.listen(states.add);
      await c.playRange(
        start: const AyahIdentifier(surah: 9, ayah: 0),
        end: const AyahIdentifier(surah: 9, ayah: 4),
      );
      await sub.cancel();
      const normalised = AyahIdentifier(surah: 9, ayah: 1);
      expect(states.first.requestedAyah, normalised);
      expect(states.first.error, isNull);
      expect(states.first.rangeStart, normalised);
      await c.close();
    },
  );

  test('setReciter on an active ayah clears a stale error', () async {
    when(() => repo.stop()).thenAnswer((_) async {});
    stubPrepareOk();
    stubPlay();
    final c = build()
      ..emit(
        const PlaybackState(currentAyah: ayah25, isPaused: true, error: 'x'),
      );
    await c.setReciter(Reciter.sudais);
    expect(c.state.error, isNull);
    await c.close();
  });

  test('a superseded play of the same ayah leaves no error', () async {
    final first = Completer<Either<Failure, void>>();
    var plays = 0;
    stubPrepareOk();
    when(() => repo.notifyAyahChanged(any())).thenReturn(null);
    when(() => repo.playPreparedAudio(any())).thenAnswer(
      (_) => ++plays == 1 ? first.future : Future.value(const Right(null)),
    );
    final c = build();
    final firstPlay = c.playSelected(ayah25);
    await Future<void>.delayed(Duration.zero);
    await c.playSelected(ayah25);
    first.complete(const Left(UnknownFailure('Loading interrupted')));
    await firstPlay;
    expect(c.state.error, isNull);
    await c.close();
  });

  test('a play cut off by stop leaves no error', () async {
    final first = Completer<Either<Failure, void>>();
    stubPrepareOk();
    when(() => repo.notifyAyahChanged(any())).thenReturn(null);
    when(() => repo.stop()).thenAnswer((_) async {});
    when(() => repo.playPreparedAudio(any())).thenAnswer((_) => first.future);
    final c = build();
    final play = c.playSelected(ayah25);
    await Future<void>.delayed(Duration.zero);
    await c.stop();
    first.complete(const Left(UnknownFailure('Loading interrupted')));
    await play;
    expect(c.state.error, isNull);
    await c.close();
  });

  test('a repeat failure after a skip shows again', () async {
    stubPrepareFails();
    when(
      () => seq.getNextAyah(current: any(named: 'current')),
    ).thenReturn(ayah26);
    final c = build()..emit(const PlaybackState(currentAyah: ayah25));
    final errors = <String?>[];
    final sub = c.stream.map((s) => s.error).listen(errors.add);
    await c.skipNext();
    await c.skipNext();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    final shown = [
      for (var i = 0; i < errors.length; i++)
        if (errors[i] != null) i,
    ];
    expect(shown.length, 2);
    expect(errors.sublist(shown[0], shown[1]).contains(null), isTrue);
    await c.close();
  });

  test(
    'advancing to an ayah whose preload failed surfaces the error naming it',
    () async {
      final done = StreamController<void>.broadcast();
      when(() => repo.onAudioCompleted).thenAnswer((_) => done.stream);
      when(
        () => seq.getNextAyah(
          current: any(named: 'current'),
          endSurah: any(named: 'endSurah'),
          endAyah: any(named: 'endAyah'),
        ),
      ).thenReturn(ayah26);
      stubPrepareFails();
      final c = build()
        ..emit(const PlaybackState(currentAyah: ayah25, isAutoPlaying: true));
      done.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.requestedAyah, ayah26);
      expect(c.state.error, isNotNull);
      await c.close();
      await done.close();
    },
  );

  // ── Task 7: skipNext / skipPrevious ──────────────────────────────────────

  blocTest<PlaybackCubit, PlaybackState>(
    'skipNext from (2,5) notifies (2,6)',
    build: () {
      when(
        () => seq.getNextAyah(current: any(named: 'current')),
      ).thenReturn(const AyahIdentifier(surah: 2, ayah: 6));
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) async => const Right('/p.mp3'));
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build()..emit(
        const PlaybackState(
          currentAyah: AyahIdentifier(surah: 2, ayah: 5),
          isPlaying: true,
        ),
      );
    },
    act: (c) => c.skipNext(),
    verify: (_) => verify(
      () => repo.notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 6)),
    ).called(1),
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'skipNext when getNextAyah returns null is a no-op',
    build: () {
      when(
        () => seq.getNextAyah(current: any(named: 'current')),
      ).thenReturn(null);
      return build()..emit(
        const PlaybackState(
          currentAyah: AyahIdentifier(surah: 114, ayah: 6),
          isPlaying: true,
        ),
      );
    },
    act: (c) => c.skipNext(),
    verify: (_) => verifyNever(() => repo.notifyAyahChanged(any())),
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'skipPrevious from (2,2) notifies (2,1)',
    build: () {
      when(
        () => seq.getPreviousAyah(current: any(named: 'current')),
      ).thenReturn(const AyahIdentifier(surah: 2, ayah: 1));
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) async => const Right('/p.mp3'));
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build()..emit(
        const PlaybackState(
          currentAyah: AyahIdentifier(surah: 2, ayah: 2),
          isPlaying: true,
        ),
      );
    },
    act: (c) => c.skipPrevious(),
    verify: (_) => verify(
      () => repo.notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 1)),
    ).called(1),
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'skipPrevious at (1,1) is a no-op',
    build: () {
      when(
        () => seq.getPreviousAyah(current: any(named: 'current')),
      ).thenReturn(null);
      return build()..emit(
        const PlaybackState(
          currentAyah: AyahIdentifier(surah: 1, ayah: 1),
          isPlaying: true,
        ),
      );
    },
    act: (c) => c.skipPrevious(),
    verify: (_) => verifyNever(() => repo.notifyAyahChanged(any())),
  );

  group('range bounds', () {
    const start = AyahIdentifier(surah: 2, ayah: 5);
    const end = AyahIdentifier(surah: 2, ayah: 7);

    test('skipNext at the range end is a no-op', () async {
      when(
        () => seq.getNextAyah(
          current: any(named: 'current'),
          endSurah: any(named: 'endSurah'),
          endAyah: any(named: 'endAyah'),
        ),
      ).thenReturn(const AyahIdentifier(surah: 2, ayah: 8));
      stubPrepareOk();
      stubPlay();
      final c = build()
        ..emit(
          const PlaybackState(
            currentAyah: end,
            rangeStart: start,
            rangeEnd: end,
          ),
        );
      await c.skipNext();
      verifyNever(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      );
      await c.close();
    });

    test('skipPrevious at the range start is a no-op', () async {
      when(
        () => seq.getPreviousAyah(current: any(named: 'current')),
      ).thenReturn(const AyahIdentifier(surah: 2, ayah: 4));
      stubPrepareOk();
      stubPlay();
      final c = build()
        ..emit(
          const PlaybackState(
            currentAyah: start,
            rangeStart: start,
            rangeEnd: end,
          ),
        );
      await c.skipPrevious();
      verifyNever(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      );
      await c.close();
    });

    test(
      'skipPrevious steps from a pending request, never past the start',
      () async {
        when(
          () => seq.getPreviousAyah(current: any(named: 'current')),
        ).thenReturn(const AyahIdentifier(surah: 2, ayah: 4));
        stubPrepareOk();
        stubPlay();
        final c = build()
          ..emit(
            const PlaybackState(
              currentAyah: AyahIdentifier(surah: 2, ayah: 6),
              requestedAyah: start,
              rangeStart: start,
              rangeEnd: end,
            ),
          );
        await c.skipPrevious();
        verifyNever(
          () => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          ),
        );
        await c.close();
      },
    );

    test('skipNext steps from a pending request, never past the end', () async {
      when(
        () => seq.getNextAyah(
          current: any(named: 'current'),
          endSurah: any(named: 'endSurah'),
          endAyah: any(named: 'endAyah'),
        ),
      ).thenReturn(const AyahIdentifier(surah: 2, ayah: 8));
      stubPrepareOk();
      stubPlay();
      final c = build()
        ..emit(
          const PlaybackState(
            currentAyah: AyahIdentifier(surah: 2, ayah: 6),
            requestedAyah: end,
            rangeStart: start,
            rangeEnd: end,
          ),
        );
      await c.skipNext();
      verifyNever(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      );
      await c.close();
    });

    test('skipNext passes the range end to getNextAyah', () async {
      when(
        () => seq.getNextAyah(
          current: any(named: 'current'),
          endSurah: any(named: 'endSurah'),
          endAyah: any(named: 'endAyah'),
        ),
      ).thenReturn(ayah26);
      stubPrepareOk();
      stubPlay();
      final c = build()
        ..emit(
          const PlaybackState(
            currentAyah: start,
            rangeStart: start,
            rangeEnd: end,
          ),
        );
      await c.skipNext();
      verify(
        () => seq.getNextAyah(current: start, endSurah: 2, endAyah: 7),
      ).called(1);
      await c.close();
    });

    test('stop clears rangeStart and rangeEnd', () async {
      final c = build()
        ..emit(
          const PlaybackState(
            currentAyah: start,
            rangeStart: start,
            rangeEnd: end,
          ),
        );
      await c.stop();
      expect(c.state.rangeStart, isNull);
      expect(c.state.rangeEnd, isNull);
      await c.close();
    });

    test('playRange keeps a cross-surah range', () async {
      stubPrepareOk();
      stubPlay();
      const crossStart = AyahIdentifier(surah: 4, ayah: 176);
      const crossEnd = AyahIdentifier(surah: 5, ayah: 2);
      final c = build();
      await c.playRange(start: crossStart, end: crossEnd);
      expect(c.state.rangeStart, crossStart);
      expect(c.state.rangeEnd, crossEnd);
      await c.close();
    });
  });

  // ── Task 8: restartCurrent ───────────────────────────────────────────────

  blocTest<PlaybackCubit, PlaybackState>(
    'restartCurrent seeks to 0 and resumes',
    build: () {
      when(() => repo.seek(any())).thenAnswer((_) async {});
      when(() => repo.resume()).thenAnswer((_) async {});
      return build()..emit(const PlaybackState(currentAyah: ayah25));
    },
    act: (c) => c.restartCurrent(),
    verify: (_) {
      verify(() => repo.seek(Duration.zero)).called(1);
      verify(() => repo.resume()).called(1);
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'restartCurrent is a no-op when currentAyah is null',
    build: () => build(),
    act: (c) => c.restartCurrent(),
    verify: (_) {
      verifyNever(() => repo.seek(any()));
      verifyNever(() => repo.resume());
    },
  );

  // ── Task 9: setSpeed ─────────────────────────────────────────────────────

  blocTest<PlaybackCubit, PlaybackState>(
    'setSpeed updates state, calls repo.setSpeed, persists via settings',
    build: () => build(),
    act: (c) => c.setSpeed(1.75),
    expect: () => [isA<PlaybackState>().having((s) => s.speed, 'speed', 1.75)],
    verify: (_) {
      verify(() => repo.setSpeed(1.75)).called(1);
      expect(settings.speedUpdate, 1.75);
    },
  );

  // ── Task 10: setReciter ──────────────────────────────────────────────────

  blocTest<PlaybackCubit, PlaybackState>(
    'setReciter while idle updates state + persists, does not stop/play',
    build: () => build(),
    act: (c) => c.setReciter(Reciter.sudais),
    expect: () => [
      isA<PlaybackState>().having((s) => s.reciter, 'reciter', Reciter.sudais),
    ],
    verify: (_) {
      expect(settings.reciterUpdate, Reciter.sudais);
      verifyNever(() => repo.stop());
      verifyNever(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      );
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'setReciter while playing stops and restarts current ayah with new reciter',
    build: () {
      when(() => repo.stop()).thenAnswer((_) async {});
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) async => const Right('/p.mp3'));
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build()
        ..emit(const PlaybackState(currentAyah: ayah25, isPlaying: true));
    },
    act: (c) => c.setReciter(Reciter.sudais),
    verify: (_) {
      verify(() => repo.stop()).called(1);
      verify(
        () => repo.prepareAyahAudio(ayah: ayah25, reciter: Reciter.sudais),
      ).called(1);
    },
  );

  // ── basmala prefix for ayah 1 of non-Fatiha / non-Tawbah surahs ─────────

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((2,1)) raises then drops isPlayingBasmala around the intro',
    build: () {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        return Right('/p/${a.surah}-${a.ayah}.mp3');
      });
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 2, ayah: 1)),
    verify: (c) {
      // After onAdvanceToFinalTrack fires, the flag must be back to false.
      expect(c.state.isPlayingBasmala, isFalse);
      expect(c.state.currentAyah, const AyahIdentifier(surah: 2, ayah: 1));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((2,1)) prepares basmala then ayah and plays as a sequence',
    build: () {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        return Right('/p/${a.surah}-${a.ayah}.mp3');
      });
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 2, ayah: 1)),
    verify: (_) {
      verify(
        () => repo.prepareAyahAudio(
          ayah: const AyahIdentifier(surah: 1, ayah: 1),
          reciter: any(named: 'reciter'),
        ),
      ).called(1);
      verify(
        () => repo.prepareAyahAudio(
          ayah: const AyahIdentifier(surah: 2, ayah: 1),
          reciter: any(named: 'reciter'),
        ),
      ).called(1);
      verify(
        () => repo.playPreparedAudioSequence([
          '/p/1-1.mp3',
          '/p/2-1.mp3',
        ], onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack')),
      ).called(1);
      verifyNever(() => repo.playPreparedAudio(any()));
      // notifyAyahChanged is fired only after basmala finishes (the stub
      // invokes onAdvanceToFinalTrack synchronously above).
      verify(
        () => repo.notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 1)),
      ).called(1);
      verifyNever(
        () => repo.notifyAyahChanged(const AyahIdentifier(surah: 1, ayah: 1)),
      );
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((1,1)) does not prepend basmala (Al-Fatiha v1 IS basmala)',
    build: () {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) async => const Right('/p.mp3'));
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 1, ayah: 1)),
    verify: (_) {
      verify(
        () => repo.prepareAyahAudio(
          ayah: const AyahIdentifier(surah: 1, ayah: 1),
          reciter: any(named: 'reciter'),
        ),
      ).called(1);
      verify(() => repo.playPreparedAudio('/p.mp3')).called(1);
      verifyNever(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      );
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((9,1)) does not prepend basmala (At-Tawbah has none)',
    build: () {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((_) async => const Right('/p.mp3'));
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 9, ayah: 1)),
    verify: (_) {
      verifyNever(
        () => repo.prepareAyahAudio(
          ayah: const AyahIdentifier(surah: 1, ayah: 1),
          reciter: any(named: 'reciter'),
        ),
      );
      verify(() => repo.playPreparedAudio('/p.mp3')).called(1);
      verifyNever(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      );
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((2,0)) is redirected to ayah 1 (basmala intro + ayah 1)',
    build: () {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        return Right('/p/${a.surah}-${a.ayah}.mp3');
      });
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 2, ayah: 0)),
    verify: (c) {
      // Should run the basmala-intro path for ayah 1, not attempt to fetch
      // a non-existent (2, 0) audio file.
      verifyNever(
        () => repo.prepareAyahAudio(
          ayah: const AyahIdentifier(surah: 2, ayah: 0),
          reciter: any(named: 'reciter'),
        ),
      );
      verify(
        () => repo.prepareAyahAudio(
          ayah: const AyahIdentifier(surah: 1, ayah: 1),
          reciter: any(named: 'reciter'),
        ),
      ).called(1);
      verify(
        () => repo.prepareAyahAudio(
          ayah: const AyahIdentifier(surah: 2, ayah: 1),
          reciter: any(named: 'reciter'),
        ),
      ).called(1);
      expect(c.state.currentAyah, const AyahIdentifier(surah: 2, ayah: 1));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected falls back to ayah-only when basmala prepare fails',
    build: () {
      when(
        () => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ),
      ).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        if (a.surah == 1) return left(UnknownFailure('boom'));
        return const Right('/p/ayah.mp3');
      });
      when(
        () => repo.playPreparedAudio(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 2, ayah: 1)),
    verify: (_) {
      verify(() => repo.playPreparedAudio('/p/ayah.mp3')).called(1);
      verifyNever(
        () => repo.playPreparedAudioSequence(
          any(),
          onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
        ),
      );
    },
  );
}
