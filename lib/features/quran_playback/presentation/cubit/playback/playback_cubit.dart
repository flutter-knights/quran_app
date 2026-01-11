import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../surah/domain/entities/surah_entity.dart';
import '../../../data/repositories/helper/reciter.dart';
import '../../../data/repositories/helper/repeat_mode.dart';
import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/repositories/quran_playback_repo.dart';
import '../../../domain/services/aya_sequence_service.dart';
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
  int _repeatTimes = 1;
  int _completedCycles = 0;

  AyahIdentifier? _startAyah;

  bool _isPlayingAyah = false;

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
    _reciter = reciter;
    _endSurah = endSurah;
    _endAyah = endAyah;
    _repeatMode = repeatMode;
    _repeatTimes = repeatTimes;
    _completedCycles = 0;

    _startAyah = AyahIdentifier(surah: startSurah, ayah: startAyah);

    emit(state.copyWith(isAutoPlaying: true, isLoading: true));
    await _playAyah(_startAyah!);
  }

  Future<void> _playAyah(AyahIdentifier ayah) async {
    if (_isPlayingAyah || isClosed) return;
    _isPlayingAyah = true;

    try {
      final result = await repository.prepareAyahAudio(
        ayah: ayah,
        reciter: _reciter!,
      );

      if (isClosed) return;

      result.fold(
        (failure) {
          emit(
            state.copyWith(
              isPlaying: false,
              isLoading: false,
              error: failure.message,
            ),
          );
        },
        (path) async {
          repository.notifyAyahChanged(ayah);
          await repository.playPreparedAudio(path);
        },
      );
    } finally {
      _isPlayingAyah = false;
    }
  }

  void _handleNextAyah() {
    if (!state.isAutoPlaying || state.currentAyah == null) return;

    final next = ayahSequenceService.getNextAyah(
      current: state.currentAyah!,
      endSurah: _endSurah,
      endAyah: _endAyah,
    );

    if (next == null) {
      switch (_repeatMode) {
        case RepeatMode.once:
          stop();
          return;

        case RepeatMode.times:
          _completedCycles++;
          if (_completedCycles >= _repeatTimes) {
            stop();
            return;
          }
          break;

        case RepeatMode.infinite:
          _completedCycles = 0;
          break;
      }

      _playAyah(_startAyah!);
      return;
    }

    _playAyah(next);
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

  Future<void> stop() async {
    _completedCycles = 0;
    _repeatMode = RepeatMode.once;

    await repository.stop();
    emit(const PlaybackState());
  }

  Future<void> pause() async {
    emit(state.copyWith(isPlaying: false));
    await repository.pause();
  }

  Future<void> resume() async {
    emit(state.copyWith(isPlaying: true));
    await repository.resume();
  }

  @override
  Future<void> close() async {
    await _ayahSub.cancel();
    await _completeSub.cancel();
    return super.close();
  }
}
