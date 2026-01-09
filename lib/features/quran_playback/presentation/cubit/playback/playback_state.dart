import '../../../domain/entities/ayah_identifier.dart';

class PlaybackState {
  final AyahIdentifier? currentAyah;
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final bool isAutoPlaying;

  const PlaybackState({
    this.currentAyah,
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
    this.isAutoPlaying = false,
  });

  PlaybackState copyWith({
    AyahIdentifier? currentAyah,
    bool? isPlaying,
    bool? isLoading,
    String? error,
    bool? isAutoPlaying,
  }) {
    return PlaybackState(
      currentAyah: currentAyah ?? this.currentAyah,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying,
    );
  }
}
