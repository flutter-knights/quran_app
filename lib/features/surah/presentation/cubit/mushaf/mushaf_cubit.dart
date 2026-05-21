import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import 'mushaf_state.dart';

class MushafCubit extends Cubit<MushafState> {
  MushafCubit({
    required int initialPage,
    required ValueNotifier<AyahIdentifier?> currentAyahNotifier,
  })  : _notifier = currentAyahNotifier,
        super(MushafState.initial(initialPage)) {
    _notifier.addListener(_onPlayingAyahChanged);
    _onPlayingAyahChanged();
  }

  final ValueNotifier<AyahIdentifier?> _notifier;

  @visibleForTesting
  ValueNotifier<AyahIdentifier?> get debugNotifier => _notifier;

  void setPage(int page) {
    emit(state.copyWith(currentPage: page, clearHighlighted: true));
  }

  void toggleHighlight(AyahIdentifier ayah) {
    if (state.highlightedAyah == ayah) {
      emit(state.copyWith(clearHighlighted: true));
    } else {
      emit(state.copyWith(highlightedAyah: ayah));
    }
  }

  void clearHighlight() {
    if (state.highlightedAyah == null) return;
    emit(state.copyWith(clearHighlighted: true));
  }

  void _onPlayingAyahChanged() {
    final next = _notifier.value;
    final prevPlaying = state.playingAyah;
    if (next == null) {
      if (state.playingAyah != null) emit(state.copyWith(clearPlaying: true));
      return;
    }
    final wasFollowing =
        state.highlightedAyah != null && state.highlightedAyah == prevPlaying;
    if (wasFollowing) {
      emit(state.copyWith(playingAyah: next, highlightedAyah: next));
    } else if (state.playingAyah != next) {
      emit(state.copyWith(playingAyah: next));
    }
  }

  @override
  Future<void> close() {
    _notifier.removeListener(_onPlayingAyahChanged);
    return super.close();
  }
}
