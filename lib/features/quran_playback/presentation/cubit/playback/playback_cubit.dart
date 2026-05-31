import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../../surah/domain/entities/surah_entity.dart';
import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/entities/reciter.dart';
import '../../../domain/repositories/quran_playback_repo.dart';
import '../../../domain/services/aya_sequence_service.dart';
import '../../../domain/services/quran_page_service.dart';
import 'playback_state.dart';

enum PlaybackStepKind { repeatAyah, advance, restartRange, stop }

class PlaybackStep {
  const PlaybackStep(this.kind,
      {this.ayah, this.nextPlayCount = 1, this.nextPass = 1});
  final PlaybackStepKind kind;
  final AyahIdentifier? ayah;
  final int nextPlayCount;
  final int nextPass;
}

/// Pure decision: given the current state, what plays next when the current
/// ayah's audio completes? No side effects — the cubit applies the result.
PlaybackStep nextPlaybackStep(PlaybackState s, AyahSequenceService seq) {
  final current = s.currentAyah;
  if (current == null) return const PlaybackStep(PlaybackStepKind.stop);

  // 1) Repeat the same ayah if more plays remain (or each-ayah is infinite).
  final eachInfinite =
      s.infiniteRepeat && s.infiniteTarget == RepeatTarget.eachAyah;
  if (eachInfinite || s.currentAyahPlayCount < s.eachAyahRepeat) {
    return PlaybackStep(
      PlaybackStepKind.repeatAyah,
      ayah: current,
      nextPlayCount: s.currentAyahPlayCount + 1,
      nextPass: s.currentRangePass,
    );
  }

  // 2) Try to advance within the range.
  final next = seq.getNextAyah(
    current: current,
    endSurah: s.rangeEnd?.surah,
    endAyah: s.rangeEnd?.ayah,
  );
  if (next != null) {
    return PlaybackStep(
      PlaybackStepKind.advance,
      ayah: next,
      nextPlayCount: 1,
      nextPass: s.currentRangePass,
    );
  }

  // 3) Hit the range end. Loop the range if repeats remain (or infinite range).
  final rangeInfinite =
      s.infiniteRepeat && s.infiniteTarget == RepeatTarget.range;
  if (rangeInfinite || s.currentRangePass < s.rangeRepeat) {
    final start = s.rangeStart ?? current;
    return PlaybackStep(
      PlaybackStepKind.restartRange,
      ayah: start,
      nextPlayCount: 1,
      nextPass: s.currentRangePass + 1,
    );
  }

  return const PlaybackStep(PlaybackStepKind.stop);
}

class PlaybackCubit extends Cubit<PlaybackState> {
  final AyahSequenceService ayahSequenceService;
  final QuranPlaybackRepo repository;
  final QuranPageService pageService;
  final SettingsCubit settingsCubit;

  late final StreamSubscription _ayahSub;
  late final StreamSubscription _completeSub;

  int? _endSurah;
  int? _endAyah;

  /// Tracks the most recently requested ayah. Used as the race guard:
  /// after an async prepare, if _inFlightAyah has changed, the older
  /// call returns early without calling notifyAyahChanged.
  AyahIdentifier? _inFlightAyah;

  PlaybackCubit({
    required this.ayahSequenceService,
    required this.repository,
    required this.pageService,
    required this.settingsCubit,
  }) : super(PlaybackState(
          speed: settingsCubit.state.settingsModel.playbackSpeed,
          reciter: settingsCubit.state.settingsModel.defaultReciter,
        )) {
    _ayahSub = repository.currentAyahStream.listen((ayah) {
      if (isClosed) return;
      emit(state.copyWith(
        currentAyah: ayah,
        isPlaying: true,
        isPaused: false,
        isLoading: false,
      ));
      _preloadNextAyahs(ayah);
    });

    _completeSub = repository.onAudioCompleted.listen((_) {
      _handleNextAyah();
    });
  }

  Future<void> playSelected(AyahIdentifier ayah) async {
    // (surah, 0) is the basmala header on the page — it has no per-ayah audio
    // file in the API. Treat a tap on it as "play ayah 1 of this surah", which
    // already prepends the basmala intro.
    if (ayah.ayah == 0) {
      ayah = AyahIdentifier(surah: ayah.surah, ayah: 1);
    }
    _endSurah = null;
    _endAyah = null;
    emit(state.copyWith(
      clearRange: true,
      currentAyahPlayCount: 1,
      currentRangePass: 1,
      isAutoPlaying: true,
      isLoading: true,
    ));
    await _playAyah(ayah);
  }

  /// Plays [start]..[end] (single surah) with the current repeat settings.
  Future<void> playRange({
    required AyahIdentifier start,
    required AyahIdentifier end,
  }) async {
    _endSurah = end.surah;
    _endAyah = end.ayah;
    emit(state.copyWith(
      rangeStart: start,
      rangeEnd: end,
      isAutoPlaying: true,
      isLoading: true,
      currentAyahPlayCount: 1,
      currentRangePass: 1,
    ));
    await _playAyah(start.ayah == 0
        ? AyahIdentifier(surah: start.surah, ayah: 1)
        : start);
  }

  Future<void> _playAyah(AyahIdentifier ayah) async {
    if (isClosed) return;
    _inFlightAyah = ayah;

    // Prepare the basmala when starting any surah other than Al-Fatiha (1) or
    // At-Tawbah (9), so the canonical opening verse plays before ayah 1. The
    // reciter is captured once at the top of the call; a mid-flight
    // `setReciter` cancels this run via `stop()` → `_inFlightAyah = null`, so
    // the two prepare calls always use the same reciter.
    String? basmalaPath;
    if (ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9) {
      final basmalaResult = await repository.prepareAyahAudio(
        ayah: const AyahIdentifier(surah: 1, ayah: 1),
        reciter: state.reciter,
      );
      if (isClosed) return;
      if (_inFlightAyah != ayah) return;
      basmalaPath = basmalaResult.fold((_) => null, (p) => p);
    }

    final result = await repository.prepareAyahAudio(
      ayah: ayah,
      reciter: state.reciter,
    );

    if (isClosed) return;
    if (_inFlightAyah != ayah) return; // race guard

    await result.fold(
      (failure) async {
        emit(state.copyWith(
          isPlaying: false,
          isLoading: false,
          isPlayingBasmala: false,
          error: failure.message,
        ));
      },
      (path) async {
        await repository.setSpeed(state.speed);
        if (basmalaPath != null) {
          // During basmala: set the target as currentAyah so the overlay
          // shows pause/playing, but raise `isPlayingBasmala` so the page
          // painter suppresses the highlight until basmala finishes. Once the
          // player advances to the final track, drop the flag and notify so
          // the verse lights up and preloads kick in.
          emit(state.copyWith(
            currentAyah: ayah,
            isPlaying: true,
            isPaused: false,
            isLoading: false,
            isPlayingBasmala: true,
          ));
          await repository.playPreparedAudioSequence(
            [basmalaPath, path],
            onAdvanceToFinalTrack: () {
              if (isClosed) return;
              if (_inFlightAyah != ayah) return;
              emit(state.copyWith(isPlayingBasmala: false));
              repository.notifyAyahChanged(ayah);
            },
          );
        } else {
          repository.notifyAyahChanged(ayah);
          await repository.playPreparedAudio(path);
        }
      },
    );
  }

  void _handleNextAyah() {
    if (!state.isAutoPlaying || state.currentAyah == null) return;
    final step = nextPlaybackStep(state, ayahSequenceService);
    switch (step.kind) {
      case PlaybackStepKind.stop:
        stop();
        return;
      case PlaybackStepKind.repeatAyah:
        emit(state.copyWith(currentAyahPlayCount: step.nextPlayCount));
        _playAyah(step.ayah!);
        return;
      case PlaybackStepKind.advance:
        emit(state.copyWith(
          currentAyahPlayCount: step.nextPlayCount,
          currentRangePass: step.nextPass,
        ));
        _playAyah(step.ayah!);
        return;
      case PlaybackStepKind.restartRange:
        emit(state.copyWith(
          currentAyahPlayCount: step.nextPlayCount,
          currentRangePass: step.nextPass,
        ));
        _playAyah(step.ayah!);
        return;
    }
  }

  Future<void> _preloadNextAyahs(AyahIdentifier current) async {
    final nextAyahs = ayahSequenceService.getNextAyahs(
      current: current,
      count: 5,
      endSurah: _endSurah,
      endAyah: _endAyah,
    );
    await repository.preloadAyahs(ayahs: nextAyahs, reciter: state.reciter);
  }

  Future<void> preloadFullSurah({
    required SurahEntity surah,
    required Reciter reciter,
  }) async {
    final ayahs = List.generate(
      surah.numberOfAyahs,
      (i) => AyahIdentifier(surah: surah.number, ayah: i + 1),
    );
    emit(state.copyWith(isLoading: true));
    await repository.preloadAyahs(ayahs: ayahs, reciter: reciter);
    emit(state.copyWith(isLoading: false));
  }

  int? getPageForCurrentAyah() {
    final ayah = state.currentAyah;
    if (ayah == null) return null;
    return pageService.getPageForAyah(ayah.surah, ayah.ayah);
  }

  Future<void> playFromAyah(AyahIdentifier ayah) => playSelected(ayah);

  Future<void> skipNext() async {
    final current = state.currentAyah;
    if (current == null) return;
    final next = ayahSequenceService.getNextAyah(current: current);
    if (next == null) return;
    await _playAyah(next);
  }

  Future<void> skipPrevious() async {
    final current = state.currentAyah;
    if (current == null) return;
    final prev = ayahSequenceService.getPreviousAyah(current: current);
    if (prev == null) return;
    await _playAyah(prev);
  }

  Future<void> restartCurrent() async {
    if (state.currentAyah == null) return;
    await repository.seek(Duration.zero);
    await repository.resume();
    emit(state.copyWith(isPlaying: true, isPaused: false));
  }

  Future<void> setSpeed(double speed) async {
    emit(state.copyWith(speed: speed));
    await repository.setSpeed(speed);
    settingsCubit.updatePlaybackSpeed(speed);
  }

  void setEachAyahRepeat(int value) =>
      emit(state.copyWith(eachAyahRepeat: value));

  void setRangeRepeat(int value) => emit(state.copyWith(rangeRepeat: value));

  void setInfiniteRepeat(bool value, RepeatTarget target) =>
      emit(state.copyWith(infiniteRepeat: value, infiniteTarget: target));

  /// Updates the active range end live (used by the expanded panel).
  void setRangeEnd(AyahIdentifier end) {
    _endSurah = end.surah;
    _endAyah = end.ayah;
    emit(state.copyWith(rangeEnd: end));
  }

  Future<void> setReciter(Reciter reciter) async {
    final wasActive =
        state.currentAyah != null && (state.isPlaying || state.isPaused);
    final activeAyah = state.currentAyah;
    emit(state.copyWith(reciter: reciter));
    settingsCubit.updateDefaultReciter(reciter);
    if (wasActive && activeAyah != null) {
      await repository.stop();
      await _playAyah(activeAyah);
    }
  }

  void autoPlayPage(int pageNumber) {
    final startAyah = pageService.getFirstAyahOfPage(pageNumber);
    if (startAyah == null) return;
    playSelected(startAyah);
  }

  Future<void> stop() async {
    _inFlightAyah = null;
    await repository.stop();
    emit(state.copyWith(
      isPlaying: false,
      isPaused: false,
      isAutoPlaying: false,
      isLoading: false,
      isPlayingBasmala: false,
      clearCurrentAyah: true,
    ));
  }

  Future<void> pause() async {
    emit(state.copyWith(isPlaying: false, isPaused: true));
    await repository.pause();
  }

  Future<void> resume() async {
    emit(state.copyWith(isPlaying: true, isPaused: false));
    await repository.resume();
  }

  @override
  Future<void> close() async {
    await _ayahSub.cancel();
    await _completeSub.cancel();
    return super.close();
  }
}
