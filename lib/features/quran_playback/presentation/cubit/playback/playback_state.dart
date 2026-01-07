import '../../../domain/entities/ayah_identifier.dart';

class PlaybackState {
  final AyahIdentifier? currentAyah;
  final bool isPlaying;
  final String? error;

  const PlaybackState({this.currentAyah, this.isPlaying = false, this.error});

  PlaybackState copyWith({
    AyahIdentifier? currentAyah,
    bool? isPlaying,
    String? error,
  }) {
    return PlaybackState(
      currentAyah: currentAyah ?? this.currentAyah,
      isPlaying: isPlaying ?? this.isPlaying,
      error: error,
    );
  }
}
