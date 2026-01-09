import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';

import '../../../data/repositories/helper/reciter.dart';
import '../../../data/repositories/helper/repeat_mode.dart';
import '../../../domain/entities/ayah_identifier.dart';
import 'playback_state.dart';

class PlaybackCubit extends Cubit<PlaybackState> {
  final AyahSequenceService ayahSequenceService;
  final QuranPlaybackRepo repository;
  late final StreamSubscription _ayahSub;
  late final StreamSubscription _completeSub;

  Reciter? _reciter;
  int? _endSurah;
  int? _endAyah;
  RepeatMode _repeatMode = RepeatMode.once;
  int _repeatTimes = 1; // used only for RepeatMode.times
  int _currentRepeat = 0;

  AyahIdentifier? _startAyah;

  PlaybackCubit({required this.ayahSequenceService, required this.repository})
    : super(const PlaybackState()) {
    _ayahSub = repository.currentAyahStream.listen((ayah) {
      if (isClosed) return;

      emit(
        state.copyWith(currentAyah: ayah, isPlaying: true, isLoading: false),
      );
      _preloadNextAyahs(ayah);
    });

    _completeSub = repository.onAudioCompleted.listen((_) {
      _handleNextAyah();
    });
  }

  Future<void> startAutoPlay({
    required int startSurah,
    required int startAyah,
    required Reciter reciter,
    int? endSurah,
    int? endAyah,
    RepeatMode repeatMode = RepeatMode.once,
    int repeatTimes = 1,
  }) async {
    if (isClosed) return;

    _reciter = reciter;
    _endSurah = endSurah;
    _endAyah = endAyah;
    _repeatMode = repeatMode;
    _repeatTimes = repeatTimes;
    _currentRepeat = 0;

    _startAyah = AyahIdentifier(surah: startSurah, ayah: startAyah);

    emit(state.copyWith(isAutoPlaying: true, isLoading: true, error: null));

    await _playAyah(_startAyah!);
  }

  Future<void> _playAyah(AyahIdentifier ayah) async {
    if (isClosed) return;

    emit(state.copyWith(isLoading: true));

    final result = await repository.prepareAyahAudio(
      ayah: ayah,
      reciter: _reciter!,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        if (isClosed) return;
        emit(
          state.copyWith(
            isPlaying: false,
            isLoading: false,
            error: failure.message,
          ),
        );
      },
      (path) async {
        if (isClosed) return;

        repository.notifyAyahChanged(ayah);
        await repository.playPreparedAudio(path);
      },
    );
  }

  Future<void> preloadFullSurah({
    required int surah,
    required Reciter reciter,
  }) async {
    final totalAyahs = quran.getVerseCount(surah);

    final ayahs = List.generate(
      totalAyahs,
      (i) => AyahIdentifier(surah: surah, ayah: i + 1),
    );

    emit(state.copyWith(isLoading: true));

    await repository.preloadAyahs(ayahs: ayahs, reciter: reciter);

    emit(state.copyWith(isLoading: false));
  }

  Future<void> _preloadNextAyahs(AyahIdentifier current) async {
    if (_reciter == null) return;

    final nextAyahs = ayahSequenceService.getNextAyahs(
      current: current,
      count: 5,
      endSurah: _endSurah,
      endAyah: _endAyah,
    );

    repository.preloadAyahs(ayahs: nextAyahs, reciter: _reciter!);
  }

  void _handleNextAyah() {
    if (!state.isAutoPlaying || state.currentAyah == null) return;

    final next = ayahSequenceService.getNextAyah(
      current: state.currentAyah!,
      endSurah: _endSurah,
      endAyah: _endAyah,
    );

    // If range finished
    if (next == null) {
      switch (_repeatMode) {
        case RepeatMode.once:
          stop();
          return;

        case RepeatMode.times:
          _currentRepeat++;
          if (_currentRepeat >= _repeatTimes) {
            stop();
            return;
          }
          break;

        case RepeatMode.infinite:
          // do nothing, just restart
          break;
      }

      // Restart from beginning of range
      _playAyah(_startAyah!);
      return;
    }

    _playAyah(next);
  }

  Future<void> stop() async {
    await repository.stop();
    emit(
      state.copyWith(isPlaying: false, isAutoPlaying: false, isLoading: false),
    );
  }

  @override
  Future<void> close() {
    _ayahSub.cancel();
    _completeSub.cancel();
    return super.close();
  }
}
