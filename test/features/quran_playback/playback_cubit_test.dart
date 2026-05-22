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
  void updateSettings({bool? isDarkMode, bool? isFormat12Hours, bool? isArabic}) {}
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
    settings = _FakeSettings(SettingsState(SettingsModel(
      isDarkMode: true,
      isFormat12Hours: true,
      isArabic: true,
      playbackSpeed: 1.25,
      defaultReciter: Reciter.husary,
    )));
    when(() => repo.currentAyahStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => repo.onAudioCompleted).thenAnswer((_) => const Stream.empty());
    when(() => repo.preloadAyahs(
          ayahs: any(named: 'ayahs'),
          reciter: any(named: 'reciter'),
        )).thenAnswer((_) async {});
    when(() => repo.setSpeed(any())).thenAnswer((_) async {});
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
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) {
        call++;
        if (call == 1) return completerA.future;
        return Future.value(const Right('/path/B.mp3'));
      });
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) async {
      // Fire A; do not await — completerA never completes so awaiting would hang
      // ignore: unawaited_futures
      c.playSelected(const AyahIdentifier(surah: 2, ayah: 1));
      // Fire B and await — this completes, sets _inFlightAyah to B's ayah
      await c.playSelected(const AyahIdentifier(surah: 2, ayah: 2));
    },
    verify: (_) {
      verify(() => repo.notifyAyahChanged(
          const AyahIdentifier(surah: 2, ayah: 2))).called(1);
      verifyNever(() => repo.notifyAyahChanged(
          const AyahIdentifier(surah: 2, ayah: 1)));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected applies the cubit speed via repo.setSpeed',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(ayah25),
    verify: (_) => verify(() => repo.setSpeed(1.25)).called(1),
  );

  // ── Task 7: skipNext / skipPrevious ──────────────────────────────────────

  blocTest<PlaybackCubit, PlaybackState>(
    'skipNext from (2,5) notifies (2,6)',
    build: () {
      when(() => seq.getNextAyah(current: any(named: 'current')))
          .thenReturn(const AyahIdentifier(surah: 2, ayah: 6));
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build()
        ..emit(const PlaybackState(
            currentAyah: AyahIdentifier(surah: 2, ayah: 5), isPlaying: true));
    },
    act: (c) => c.skipNext(),
    verify: (_) => verify(() =>
        repo.notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 6))).called(1),
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'skipNext when getNextAyah returns null is a no-op',
    build: () {
      when(() => seq.getNextAyah(current: any(named: 'current')))
          .thenReturn(null);
      return build()
        ..emit(const PlaybackState(
            currentAyah: AyahIdentifier(surah: 114, ayah: 6),
            isPlaying: true));
    },
    act: (c) => c.skipNext(),
    verify: (_) =>
        verifyNever(() => repo.notifyAyahChanged(any())),
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'skipPrevious from (2,2) notifies (2,1)',
    build: () {
      when(() => seq.getPreviousAyah(current: any(named: 'current')))
          .thenReturn(const AyahIdentifier(surah: 2, ayah: 1));
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build()
        ..emit(const PlaybackState(
            currentAyah: AyahIdentifier(surah: 2, ayah: 2), isPlaying: true));
    },
    act: (c) => c.skipPrevious(),
    verify: (_) => verify(() =>
        repo.notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 1))).called(1),
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'skipPrevious at (1,1) is a no-op',
    build: () {
      when(() => seq.getPreviousAyah(current: any(named: 'current')))
          .thenReturn(null);
      return build()
        ..emit(const PlaybackState(
            currentAyah: AyahIdentifier(surah: 1, ayah: 1),
            isPlaying: true));
    },
    act: (c) => c.skipPrevious(),
    verify: (_) =>
        verifyNever(() => repo.notifyAyahChanged(any())),
  );

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
    expect: () => [
      isA<PlaybackState>().having((s) => s.speed, 'speed', 1.75),
    ],
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
      verifyNever(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          ));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'setReciter while playing stops and restarts current ayah with new reciter',
    build: () {
      when(() => repo.stop()).thenAnswer((_) async {});
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build()
        ..emit(const PlaybackState(
          currentAyah: ayah25,
          isPlaying: true,
        ));
    },
    act: (c) => c.setReciter(Reciter.sudais),
    verify: (_) {
      verify(() => repo.stop()).called(1);
      verify(() => repo.prepareAyahAudio(
            ayah: ayah25,
            reciter: Reciter.sudais,
          )).called(1);
    },
  );

  // ── basmala prefix for ayah 1 of non-Fatiha / non-Tawbah surahs ─────────

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((2,1)) raises then drops isPlayingBasmala around the intro',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        return Right('/p/${a.surah}-${a.ayah}.mp3');
      });
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).thenAnswer((inv) async {
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
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        return Right('/p/${a.surah}-${a.ayah}.mp3');
      });
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 2, ayah: 1)),
    verify: (_) {
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 1, ayah: 1),
            reciter: any(named: 'reciter'),
          )).called(1);
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 2, ayah: 1),
            reciter: any(named: 'reciter'),
          )).called(1);
      verify(() => repo.playPreparedAudioSequence(
            ['/p/1-1.mp3', '/p/2-1.mp3'],
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).called(1);
      verifyNever(() => repo.playPreparedAudio(any()));
      // notifyAyahChanged is fired only after basmala finishes (the stub
      // invokes onAdvanceToFinalTrack synchronously above).
      verify(() => repo
          .notifyAyahChanged(const AyahIdentifier(surah: 2, ayah: 1))).called(1);
      verifyNever(() => repo
          .notifyAyahChanged(const AyahIdentifier(surah: 1, ayah: 1)));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((1,1)) does not prepend basmala (Al-Fatiha v1 IS basmala)',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 1, ayah: 1)),
    verify: (_) {
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 1, ayah: 1),
            reciter: any(named: 'reciter'),
          )).called(1);
      verify(() => repo.playPreparedAudio('/p.mp3')).called(1);
      verifyNever(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          ));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((9,1)) does not prepend basmala (At-Tawbah has none)',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).thenAnswer((inv) async {
        (inv.namedArguments[#onAdvanceToFinalTrack] as void Function()?)
            ?.call();
        return const Right(null);
      });
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 9, ayah: 1)),
    verify: (_) {
      verifyNever(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 1, ayah: 1),
            reciter: any(named: 'reciter'),
          ));
      verify(() => repo.playPreparedAudio('/p.mp3')).called(1);
      verifyNever(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          ));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((2,0)) is redirected to ayah 1 (basmala intro + ayah 1)',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        return Right('/p/${a.surah}-${a.ayah}.mp3');
      });
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).thenAnswer((inv) async {
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
      verifyNever(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 2, ayah: 0),
            reciter: any(named: 'reciter'),
          ));
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 1, ayah: 1),
            reciter: any(named: 'reciter'),
          )).called(1);
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 2, ayah: 1),
            reciter: any(named: 'reciter'),
          )).called(1);
      expect(c.state.currentAyah, const AyahIdentifier(surah: 2, ayah: 1));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected falls back to ayah-only when basmala prepare fails',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((inv) async {
        final a = inv.namedArguments[#ayah] as AyahIdentifier;
        if (a.surah == 1) return left(UnknownFailure('boom'));
        return const Right('/p/ayah.mp3');
      });
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          )).thenAnswer((inv) async {
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
      verifyNever(() => repo.playPreparedAudioSequence(
            any(),
            onAdvanceToFinalTrack: any(named: 'onAdvanceToFinalTrack'),
          ));
    },
  );
}
