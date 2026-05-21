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
    registerFallbackValue(Duration.zero);
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
}
