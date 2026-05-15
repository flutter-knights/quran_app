import 'package:equatable/equatable.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';

class MushafState extends Equatable {
  final int currentPage;
  final AyahIdentifier? highlightedAyah;
  final AyahIdentifier? playingAyah;

  const MushafState({
    required this.currentPage,
    this.highlightedAyah,
    this.playingAyah,
  });

  factory MushafState.initial(int page) =>
      MushafState(currentPage: page);

  MushafState copyWith({
    int? currentPage,
    AyahIdentifier? highlightedAyah,
    AyahIdentifier? playingAyah,
    bool clearHighlighted = false,
    bool clearPlaying = false,
  }) {
    return MushafState(
      currentPage: currentPage ?? this.currentPage,
      highlightedAyah:
          clearHighlighted ? null : (highlightedAyah ?? this.highlightedAyah),
      playingAyah: clearPlaying ? null : (playingAyah ?? this.playingAyah),
    );
  }

  @override
  List<Object?> get props => [currentPage, highlightedAyah, playingAyah];
}
