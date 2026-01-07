import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';

import '../../../data/repositories/reciter.dart';
import '../../../domain/entities/ayah_identifier.dart';
import 'playback_state.dart';

class PlaybackCubit extends Cubit<PlaybackState> {
  final QuranPlaybackRepo repository;
  late final StreamSubscription _sub;

  PlaybackCubit(this.repository) : super(const PlaybackState()) {
    _sub = repository.currentAyahStream.listen((ayah) {
      emit(state.copyWith(currentAyah: ayah, isPlaying: true));
    });
  }

  Future<void> playAyah({
    required int surah,
    required int ayah,
    required Reciter reciter,
  }) async {
    final ayahId = AyahIdentifier(surah: surah, ayah: ayah);

    emit(state.copyWith(currentAyah: ayahId, isPlaying: true));

    final prepared = await repository.prepareAyahAudio(
      ayah: ayahId,
      reciter: reciter,
    );

    prepared.fold(
      (failure) {
        print("a7777a");
        print(failure.message);

        emit(state.copyWith(isPlaying: false, error: failure.message));
      },
      (localPath) async {
        repository.notifyAyahChanged(ayahId);
        await repository.playPreparedAudio(localPath);
      },
    );
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
