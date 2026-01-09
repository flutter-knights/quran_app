import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';

import '../../../data/repositories/reciter.dart';
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

  PlaybackCubit({required this.ayahSequenceService, required this.repository})
    : super(const PlaybackState()) {
    _ayahSub = repository.currentAyahStream.listen((ayah) {
      emit(
        state.copyWith(currentAyah: ayah, isPlaying: true, isLoading: false),
      );
      _preloadNextAyahs(ayah);
    });

    _completeSub = repository.onAudioCompleted.listen((_) {
      _handleNextAyah();
    });
  }

  /// ▶️ Start auto play
  Future<void> startAutoPlay({
    required int startSurah,
    required int startAyah,
    required Reciter reciter,
    int? endSurah,
    int? endAyah,
  }) async {
    _reciter = reciter;
    _endSurah = endSurah;
    _endAyah = endAyah;

    emit(state.copyWith(isAutoPlaying: true, isLoading: true, error: null));

    await _playAyah(AyahIdentifier(surah: startSurah, ayah: startAyah));
  }

  Future<void> _playAyah(AyahIdentifier ayah) async {
    emit(state.copyWith(isLoading: true));

    final result = await repository.prepareAyahAudio(
      ayah: ayah,
      reciter: _reciter!,
    );

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
  }

  Future<void> preloadFullSurah({
    required int surah,
    required Reciter reciter,
  }) async {
    final totalAyahs = quran.getVerseCount(surah);

    emit(state.copyWith(isLoading: true));

    for (int ayah = 1; ayah <= totalAyahs; ayah++) {
      await repository.prepareAyahAudio(
        ayah: AyahIdentifier(surah: surah, ayah: ayah),
        reciter: reciter,
      );
    }

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

    for (final ayah in nextAyahs) {
      // 🔥 fire-and-forget
      repository.prepareAyahAudio(ayah: ayah, reciter: _reciter!);
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
      stop();
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
