import 'package:equatable/equatable.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../domain/entities/ayah_bound_entity.dart';
import '../../utils/mushaf_args.dart';
import '../../utils/page_bounds.dart';

class MushafState extends Equatable {
  final int currentPage;
  final AyahIdentifier? selectedAyah;
  final AyahIdentifier? playingAyah;
  final bool followPlayback;
  final int? openedSurah;
  final List<AyahBoundEntity> pageAyahs;
  final int? jumpFrom;

  const MushafState({
    required this.currentPage,
    this.selectedAyah,
    this.playingAyah,
    this.followPlayback = true,
    this.openedSurah,
    this.pageAyahs = const [],
    this.jumpFrom,
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
    int? jumpFrom,
    bool clearSelected = false,
    bool clearPlaying = false,
    bool clearJumpFrom = false,
  }) {
    return MushafState(
      currentPage: currentPage ?? this.currentPage,
      selectedAyah: clearSelected ? null : (selectedAyah ?? this.selectedAyah),
      playingAyah: clearPlaying ? null : (playingAyah ?? this.playingAyah),
      followPlayback: followPlayback ?? this.followPlayback,
      openedSurah: openedSurah,
      pageAyahs: pageAyahs ?? this.pageAyahs,
      jumpFrom: clearJumpFrom ? null : (jumpFrom ?? this.jumpFrom),
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
    jumpFrom,
  ];
}
