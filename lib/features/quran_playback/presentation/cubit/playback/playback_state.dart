import '../../../domain/entities/ayah_identifier.dart';

class PlaybackState {
  final AyahIdentifier? currentAyah;
  final bool isPlaying;
  final bool isAutoPlaying;
  final bool isLoading;
  final String? error;

  const PlaybackState({
    this.currentAyah,
    this.isPlaying = false,
    this.isAutoPlaying = false,
    this.isLoading = false,
    this.error,
  });

  PlaybackState copyWith({
    AyahIdentifier? currentAyah,
    bool? isPlaying,
    bool? isAutoPlaying,
    bool? isLoading,
    String? error,
  }) {
    return PlaybackState(
      currentAyah: currentAyah ?? this.currentAyah,
      isPlaying: isPlaying ?? this.isPlaying,
      isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
