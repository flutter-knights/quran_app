import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/entities/reciter.dart';
import '../../../domain/repositories/quran_playback_repo.dart';
import '../../../domain/services/aya_sequence_service.dart';
import '../../../domain/services/quran_page_service.dart';
import 'playback_state.dart';

enum PlaybackStepKind { repeatAyah, advance, restartRange, stop }

class PlaybackStep {
  const PlaybackStep(
    this.kind, {
    this.ayah,
    this.nextPlayCount = 1,
    this.nextPass = 1,
  });
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

  int _playGeneration = 0;
  var _held = false;
  AyahIdentifier? _heldAyah;

  PlaybackCubit({
    required this.ayahSequenceService,
    required this.repository,
    required this.pageService,
    required this.settingsCubit,
  }) : super(
         PlaybackState(
           speed: settingsCubit.state.settingsModel.playbackSpeed,
           reciter: settingsCubit.state.settingsModel.defaultReciter,
         ),
       ) {
    _ayahSub = repository.currentAyahStream.listen((ayah) {
      if (isClosed) return;
      emit(
        state.copyWith(
          currentAyah: ayah,
          isPlaying: true,
          isPaused: false,
          isLoading: false,
          clearError: true,
        ),
      );
      _preloadNextAyahs(ayah);
    });

    _completeSub = repository.onAudioCompleted.listen((_) {
      if (isClosed) return;
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
    _release();
    emit(
      state.copyWith(
        clearRange: true,
        currentAyahPlayCount: 1,
        currentRangePass: 1,
        isAutoPlaying: true,
        isLoading: true,
        requestedAyah: ayah,
        clearError: true,
        playedFromNetwork: false,
      ),
    );
    await _playAyah(ayah);
  }

  /// Plays [start]..[end] with the current repeat settings.
  Future<void> playRange({
    required AyahIdentifier start,
    required AyahIdentifier end,
  }) async {
    // (surah, 0) is the basmala header — normalize to ayah 1 before storing as
    // rangeStart so that restartRange also uses the valid ayah number.
    final normStart = start.ayah == 0
        ? AyahIdentifier(surah: start.surah, ayah: 1)
        : start;
    _endSurah = end.surah;
    _endAyah = end.ayah;
    _release();
    emit(
      state.copyWith(
        rangeStart: normStart,
        rangeEnd: end,
        isAutoPlaying: true,
        isLoading: true,
        currentAyahPlayCount: 1,
        currentRangePass: 1,
        requestedAyah: normStart,
        clearError: true,
        playedFromNetwork: false,
      ),
    );
    await _playAyah(normStart);
  }

  Future<void> _playAyah(AyahIdentifier ayah) async {
    if (isClosed) return;
    final generation = ++_playGeneration;
    bool stale() => isClosed || generation != _playGeneration;
    emit(state.copyWith(requestedAyah: ayah));

    // Prepare the basmala when starting any surah other than Al-Fatiha (1) or
    // At-Tawbah (9), so the canonical opening verse plays before ayah 1.
    String? basmalaPath;
    if (ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9) {
      final basmalaResult = await repository.prepareAyahAudio(
        ayah: const AyahIdentifier(surah: 1, ayah: 1),
        reciter: state.reciter,
      );
      if (stale()) return;
      basmalaPath = basmalaResult.fold((_) => null, (p) => p);
    }

    final cached = repository.isAyahCached(ayah: ayah, reciter: state.reciter);
    final result = await repository.prepareAyahAudio(
      ayah: ayah,
      reciter: state.reciter,
    );

    if (stale()) return;

    Future<void> fail(String message) async {
      if (stale()) return;
      if (state.currentAyah != null) {
        await repository.stop();
        if (stale()) return;
      }
      emit(
        state.copyWith(
          isPlaying: false,
          isLoading: false,
          isPlayingBasmala: false,
          error: message,
        ),
      );
    }

    await result.fold((failure) async => fail(failure.message), (path) async {
      await repository.setSpeed(state.speed);
      if (stale()) return;
      if (_held) {
        _heldAyah = ayah;
        emit(
          state.copyWith(
            currentAyah: ayah,
            isPlaying: false,
            isPaused: true,
            isLoading: false,
            playedFromNetwork: !cached,
          ),
        );
        return;
      }
      if (basmalaPath != null) {
        // During basmala: set the target as currentAyah so the overlay
        // shows pause/playing, but raise `isPlayingBasmala` so the page
        // painter suppresses the highlight until basmala finishes. Once the
        // player advances to the final track, drop the flag and notify so
        // the verse lights up and preloads kick in.
        emit(
          state.copyWith(
            currentAyah: ayah,
            isPlaying: true,
            isPaused: false,
            isLoading: false,
            isPlayingBasmala: true,
            playedFromNetwork: !cached,
          ),
        );
        final played = await repository.playPreparedAudioSequence(
          [basmalaPath, path],
          onAdvanceToFinalTrack: () {
            if (stale()) return;
            emit(state.copyWith(isPlayingBasmala: false));
            repository.notifyAyahChanged(ayah);
          },
        );
        await played.fold((failure) => fail(failure.message), (_) async {});
      } else {
        emit(state.copyWith(playedFromNetwork: !cached));
        repository.notifyAyahChanged(ayah);
        final played = await repository.playPreparedAudio(path);
        await played.fold((failure) => fail(failure.message), (_) async {});
      }
    });
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
        emit(
          state.copyWith(
            currentAyahPlayCount: step.nextPlayCount,
            currentRangePass: step.nextPass,
          ),
        );
        _playAyah(step.ayah!);
        return;
      case PlaybackStepKind.restartRange:
        emit(
          state.copyWith(
            currentAyahPlayCount: step.nextPlayCount,
            currentRangePass: step.nextPass,
          ),
        );
        _playAyah(step.ayah!);
        return;
    }
  }

  Future<void> _preloadNextAyahs(AyahIdentifier current) async {
    final generation = _playGeneration;
    final reciter = state.reciter;
    final nextAyahs = ayahSequenceService.getNextAyahs(
      current: current,
      count: 5,
      endSurah: _endSurah,
      endAyah: _endAyah,
    );
    await repository.preloadAyahs(ayahs: nextAyahs, reciter: reciter);
    if (nextAyahs.isEmpty) return;
    final next = nextAyahs.first;
    final prepared = await repository.prepareAyahAudio(
      ayah: next,
      reciter: reciter,
    );
    if (isClosed || generation != _playGeneration || state.error != null) {
      return;
    }
    prepared.fold(
      (failure) =>
          emit(state.copyWith(error: failure.message, requestedAyah: next)),
      (_) {},
    );
  }

  int? getPageForCurrentAyah() {
    final ayah = state.currentAyah;
    if (ayah == null) return null;
    return pageService.getPageForAyah(ayah.surah, ayah.ayah);
  }

  Future<void> playFromAyah(AyahIdentifier ayah) => playSelected(ayah);

  Future<void> retry() async {
    final ayah = state.requestedAyah;
    if (ayah == null) return;
    _release();
    emit(state.copyWith(clearError: true, isLoading: true));
    await _playAyah(ayah);
  }

  Future<void> skipNext() async {
    if (!state.canSkipNext) return;
    final current = state.skipOrigin;
    if (current == null) return;
    final next = ayahSequenceService.getNextAyah(
      current: current,
      endSurah: state.rangeEnd?.surah,
      endAyah: state.rangeEnd?.ayah,
    );
    if (next == null) return;
    _release();
    emit(state.copyWith(clearError: true));
    await _playAyah(next);
  }

  Future<void> skipPrevious() async {
    if (!state.canSkipPrevious) return;
    final current = state.skipOrigin;
    if (current == null) return;
    final prev = ayahSequenceService.getPreviousAyah(current: current);
    if (prev == null) return;
    _release();
    emit(state.copyWith(clearError: true));
    await _playAyah(prev);
  }

  Future<void> restartCurrent() async {
    if (state.currentAyah == null) return;
    if (state.error != null) return retry();
    _release();
    await repository.seek(Duration.zero);
    await repository.resume();
    emit(state.copyWith(isPlaying: true, isPaused: false));
  }

  Future<void> seek(Duration position) => repository.seek(position);

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

  /// Seeds the range without starting audio. Used to pre-populate the options
  /// sheet when an ayah is selected but playback hasn't started yet, so the
  /// sheet shows the correct surah instead of defaulting to Al-Fatiha.
  void setRange({required AyahIdentifier start, required AyahIdentifier end}) {
    _endSurah = end.surah;
    _endAyah = end.ayah;
    emit(state.copyWith(rangeStart: start, rangeEnd: end));
  }

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
    if (wasActive) _release();
    emit(state.copyWith(reciter: reciter, clearError: wasActive));
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
    final generation = ++_playGeneration;
    _release();
    await repository.stop();
    if (isClosed || generation != _playGeneration) return;
    _endSurah = null;
    _endAyah = null;
    emit(
      state.copyWith(
        clearRange: true,
        isPlaying: false,
        isPaused: false,
        isAutoPlaying: false,
        isLoading: false,
        isPlayingBasmala: false,
        clearCurrentAyah: true,
        clearRequested: true,
        clearError: true,
        playedFromNetwork: false,
      ),
    );
  }

  Future<void> pause() async {
    _held = true;
    repository.holdPlayback(true);
    emit(state.copyWith(isPlaying: false, isPaused: true));
    await repository.pause();
  }

  Future<void> resume() async {
    if (state.error != null) return retry();
    final heldAyah = _heldAyah;
    _release();
    emit(state.copyWith(isPlaying: true, isPaused: false));
    if (heldAyah != null) return _playAyah(heldAyah);
    await repository.resume();
  }

  void _release() {
    _held = false;
    _heldAyah = null;
    repository.holdPlayback(false);
  }

  @override
  Future<void> close() async {
    await _ayahSub.cancel();
    await _completeSub.cancel();
    return super.close();
  }
}
