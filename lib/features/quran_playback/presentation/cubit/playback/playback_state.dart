import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/entities/reciter.dart';

class PlaybackState {
  final AyahIdentifier? currentAyah;
  final bool isPlaying;
  final bool isPaused;
  final bool isAutoPlaying;
  final bool isLoading;

  /// True while the basmala intro is playing before ayah 1 of a surah. The
  /// overlay still reports `currentAyah` as the target verse, but the page
  /// painter suppresses the highlight so ayah 1 does not light up during the
  /// intro.
  final bool isPlayingBasmala;
  final String? error;
  final Reciter reciter;
  final double speed;

  const PlaybackState({
    this.currentAyah,
    this.isPlaying = false,
    this.isPaused = false,
    this.isAutoPlaying = false,
    this.isLoading = false,
    this.isPlayingBasmala = false,
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
    bool? isPlayingBasmala,
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
      isPlayingBasmala: isPlayingBasmala ?? this.isPlayingBasmala,
      error: error,
      reciter: reciter ?? this.reciter,
      speed: speed ?? this.speed,
    );
  }
}
