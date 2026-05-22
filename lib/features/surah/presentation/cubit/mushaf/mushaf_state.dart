import 'package:equatable/equatable.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';

class MushafState extends Equatable {
  final int currentPage;
  final AyahIdentifier? highlightedAyah;
  final AyahIdentifier? playingAyah;

  /// Normalized vertical center (0..1) of the highlighted ayah within the
  /// page. Used to decide whether the playback overlay floats at the top or
  /// bottom so it does not cover the verse.
  final double? highlightedAyahCenterY;

  /// True when the user opened the playback overlay via the FAB without
  /// selecting a verse. Lets the overlay stay visible against the current
  /// playback target instead of vanishing the moment the highlight is cleared.
  final bool isOverlayPinned;

  const MushafState({
    required this.currentPage,
    this.highlightedAyah,
    this.playingAyah,
    this.highlightedAyahCenterY,
    this.isOverlayPinned = false,
  });

  factory MushafState.initial(int page) =>
      MushafState(currentPage: page);

  MushafState copyWith({
    int? currentPage,
    AyahIdentifier? highlightedAyah,
    AyahIdentifier? playingAyah,
    double? highlightedAyahCenterY,
    bool? isOverlayPinned,
    bool clearHighlighted = false,
    bool clearPlaying = false,
    bool clearHighlightedCenterY = false,
  }) {
    return MushafState(
      currentPage: currentPage ?? this.currentPage,
      highlightedAyah:
          clearHighlighted ? null : (highlightedAyah ?? this.highlightedAyah),
      playingAyah: clearPlaying ? null : (playingAyah ?? this.playingAyah),
      highlightedAyahCenterY: clearHighlighted || clearHighlightedCenterY
          ? null
          : (highlightedAyahCenterY ?? this.highlightedAyahCenterY),
      isOverlayPinned: isOverlayPinned ?? this.isOverlayPinned,
    );
  }

  @override
  List<Object?> get props => [
        currentPage,
        highlightedAyah,
        playingAyah,
        highlightedAyahCenterY,
        isOverlayPinned,
      ];
}
