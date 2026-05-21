import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/entities/reciter.dart';

class PlaybackState {
  final AyahIdentifier? currentAyah;
  final bool isPlaying;
  final bool isPaused;
  final bool isAutoPlaying;
  final bool isLoading;
  final String? error;
  final Reciter reciter;
  final double speed;

  const PlaybackState({
    this.currentAyah,
    this.isPlaying = false,
    this.isPaused = false,
    this.isAutoPlaying = false,
    this.isLoading = false,
    this.error,
    this.reciter = Reciter.alafasy,
    this.speed = 1.0,
  });

  PlaybackState copyWith({
    AyahIdentifier? currentAyah,
    bool? isPlaying,
    bool? isPaused,
    bool? isAutoPlaying,
    bool? isLoading,
    String? error,
    Reciter? reciter,
    double? speed,
    bool clearCurrentAyah = false,
  }) {
    return PlaybackState(
      currentAyah: clearCurrentAyah ? null : (currentAyah ?? this.currentAyah),
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      reciter: reciter ?? this.reciter,
      speed: speed ?? this.speed,
    );
  }
}
