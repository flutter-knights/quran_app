import 'package:equatable/equatable.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../domain/entities/ayah_bound_entity.dart';
import '../../pages/mushaf/mushaf_args.dart';
import '../../utils/page_bounds.dart';

class MushafState extends Equatable {
  final int currentPage;
  final AyahIdentifier? selectedAyah;
  final AyahIdentifier? playingAyah;
  final bool followPlayback;
  final int? openedSurah;
  final List<AyahBoundEntity> pageAyahs;

  /// Normalized vertical center (0..1) of the highlighted ayah within the
  /// page. Used to decide whether the playback overlay floats at the top or
  /// bottom so it does not cover the verse.
  final double? highlightedAyahCenterY;

  /// True when the user opened the playback overlay via the FAB without
  /// selecting a verse. Lets the overlay stay visible against the current
  /// playback target instead of vanishing the moment the highlight is cleared.
  final bool isOverlayPinned;

  /// True when the Mushaf chrome (app bar, bottom bar, etc.) is visible.
  /// Defaults to false (chrome hidden by default).
  final bool chromeVisible;

  const MushafState({
    required this.currentPage,
    this.selectedAyah,
    this.playingAyah,
    this.followPlayback = true,
    this.openedSurah,
    this.pageAyahs = const [],
    this.highlightedAyahCenterY,
    this.isOverlayPinned = false,
    this.chromeVisible = false,
  });

  factory MushafState.initial(MushafArgs args) {
    final focus = args.focusAyah;
    return MushafState(
      currentPage: args.page,
      openedSurah: args.openedSurah,
      selectedAyah:
          args.origin == MushafOrigin.jump && focus != null && focus.ayah > 0
          ? focus
          : null,
    );
  }

  int? get runningSurah => resolveRunningSurah(
    ayahs: pageAyahs,
    selected: selectedAyah,
    playing: playingAyah,
    openedSurah: openedSurah,
  );

  MushafState copyWith({
    int? currentPage,
    AyahIdentifier? selectedAyah,
    AyahIdentifier? playingAyah,
    bool? followPlayback,
    List<AyahBoundEntity>? pageAyahs,
    double? highlightedAyahCenterY,
    bool? isOverlayPinned,
    bool? chromeVisible,
    bool clearSelected = false,
    bool clearPlaying = false,
    bool clearHighlightedCenterY = false,
  }) {
    return MushafState(
      currentPage: currentPage ?? this.currentPage,
      selectedAyah: clearSelected ? null : (selectedAyah ?? this.selectedAyah),
      playingAyah: clearPlaying ? null : (playingAyah ?? this.playingAyah),
      followPlayback: followPlayback ?? this.followPlayback,
      openedSurah: openedSurah,
      pageAyahs: pageAyahs ?? this.pageAyahs,
      highlightedAyahCenterY: clearSelected || clearHighlightedCenterY
          ? null
          : (highlightedAyahCenterY ?? this.highlightedAyahCenterY),
      isOverlayPinned: isOverlayPinned ?? this.isOverlayPinned,
      chromeVisible: chromeVisible ?? this.chromeVisible,
    );
  }

  @override
  List<Object?> get props => [
    currentPage,
    selectedAyah,
    playingAyah,
    followPlayback,
    openedSurah,
    pageAyahs,
    highlightedAyahCenterY,
    isOverlayPinned,
    chromeVisible,
  ];
}
