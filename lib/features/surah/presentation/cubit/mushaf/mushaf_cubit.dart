import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../utils/mushaf_args.dart';
import '../../utils/follow_playback.dart';
import 'mushaf_state.dart';

class MushafCubit extends Cubit<MushafState> {
  MushafCubit({
    required MushafArgs args,
    required ValueNotifier<AyahIdentifier?> currentAyahNotifier,
    required QuranPageService pageService,
    required GetMushafPage getMushafPage,
  }) : _notifier = currentAyahNotifier,
       _pageService = pageService,
       _getMushafPage = getMushafPage,
       super(MushafState.initial(args)) {
    _notifier.addListener(_onPlayingAyahChanged);
    _onPlayingAyahChanged();
    _loadPageAyahs(args.page);
  }

  final ValueNotifier<AyahIdentifier?> _notifier;
  final QuranPageService _pageService;
  final GetMushafPage _getMushafPage;

  @visibleForTesting
  ValueNotifier<AyahIdentifier?> get debugNotifier => _notifier;

  int? get playingPage {
    final playing = state.playingAyah;
    if (playing == null) return null;
    return _pageService.getPageForAyah(playing.surah, playing.realAyah);
  }

  void setPage(int page, {required bool byUser}) {
    emit(
      byUser
          ? state.copyWith(
              currentPage: page,
              pageAyahs: const [],
              clearSelected: true,
              followPlayback: followAfterManualTurn(
                followPlayback: state.followPlayback,
                newPage: page,
                playingPage: playingPage,
              ),
            )
          : state.copyWith(currentPage: page, pageAyahs: const []),
    );
    _loadPageAyahs(page);
  }

  Future<void> _loadPageAyahs(int page) async {
    final result = await _getMushafPage(page);
    if (isClosed || state.currentPage != page) return;
    result.fold((_) {}, (entity) {
      if (entity.ayahs.isEmpty && state.pageAyahs.isEmpty) return;
      emit(state.copyWith(pageAyahs: entity.ayahs));
    });
  }

  void toggleSelection(AyahIdentifier ayah) {
    if (state.selectedAyah == ayah) {
      emit(state.copyWith(clearSelected: true));
    } else {
      emit(state.copyWith(selectedAyah: ayah));
    }
  }

  void clearSelection() {
    if (state.selectedAyah == null) return;
    emit(state.copyWith(clearSelected: true));
  }

  void resumeFollow() => emit(state.copyWith(followPlayback: true));

  Future<void> reloadPageAyahs() => _loadPageAyahs(state.currentPage);

  /// Publishes the normalized vertical center of the currently highlighted
  /// ayah so the playback overlay can avoid covering it.
  void setHighlightBounds(double centerY) {
    if (state.selectedAyah == null) return;
    if (state.highlightedAyahCenterY == centerY) return;
    emit(state.copyWith(highlightedAyahCenterY: centerY));
  }

  /// Toggles the Mushaf chrome (app bar, bottom bar, etc.) visibility.
  void toggleChrome() =>
      emit(state.copyWith(chromeVisible: !state.chromeVisible));

  /// Sets the Mushaf chrome visibility explicitly.
  void setChrome(bool visible) => emit(state.copyWith(chromeVisible: visible));

  /// Shrinks the overlay back to its FAB state. Also clears any active
  /// highlight so the overlay's visibility check (`selectedAyah != null ||
  /// isOverlayPinned`) goes false.
  void unpinOverlay() {
    if (!state.isOverlayPinned && state.selectedAyah == null) return;
    emit(state.copyWith(isOverlayPinned: false, clearSelected: true));
  }

  void _onPlayingAyahChanged() {
    final next = _notifier.value;
    final prevPlaying = state.playingAyah;
    if (next == null) {
      if (state.playingAyah != null) emit(state.copyWith(clearPlaying: true));
      return;
    }
    final wasFollowing =
        state.selectedAyah != null && state.selectedAyah == prevPlaying;
    if (wasFollowing) {
      emit(state.copyWith(playingAyah: next, selectedAyah: next));
    } else if (prevPlaying != next) {
      emit(
        state.copyWith(
          playingAyah: next,
          followPlayback: prevPlaying == null ? true : null,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _notifier.removeListener(_onPlayingAyahChanged);
    return super.close();
  }
}
