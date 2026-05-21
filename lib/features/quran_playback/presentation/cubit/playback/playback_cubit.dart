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
    _endSurah = null;
    _endAyah = null;
    emit(state.copyWith(isAutoPlaying: true, isLoading: true));
    await _playAyah(ayah);
  }

  Future<void> _playAyah(AyahIdentifier ayah) async {
    if (isClosed) return;
    _inFlightAyah = ayah;

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
          error: failure.message,
        ));
      },
      (path) async {
        repository.notifyAyahChanged(ayah);
        await repository.setSpeed(state.speed);
        await repository.playPreparedAudio(path);
      },
    );
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
