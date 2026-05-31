import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/entities/reciter.dart';

/// Which repeat dimension the infinite (∞) toggle applies to.
enum RepeatTarget { eachAyah, range }

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

  /// Inclusive playback range. Null start/end = play from currentAyah to the
  /// natural end of the surah (legacy behavior).
  final AyahIdentifier? rangeStart;
  final AyahIdentifier? rangeEnd;

  /// How many times each ayah plays before advancing (1..99).
  final int eachAyahRepeat;

  /// How many times the whole range loops (1..99).
  final int rangeRepeat;

  /// When true, the [infiniteTarget] dimension repeats forever.
  final bool infiniteRepeat;
  final RepeatTarget infiniteTarget;

  /// Runtime counters (1-based): how many times the current ayah has played
  /// in this pass, and which range pass we're on.
  final int currentAyahPlayCount;
  final int currentRangePass;

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
    this.rangeStart,
    this.rangeEnd,
    this.eachAyahRepeat = 1,
    this.rangeRepeat = 1,
    this.infiniteRepeat = false,
    this.infiniteTarget = RepeatTarget.range,
    this.currentAyahPlayCount = 1,
    this.currentRangePass = 1,
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
    AyahIdentifier? rangeStart,
    AyahIdentifier? rangeEnd,
    int? eachAyahRepeat,
    int? rangeRepeat,
    bool? infiniteRepeat,
    RepeatTarget? infiniteTarget,
    int? currentAyahPlayCount,
    int? currentRangePass,
    bool clearRange = false,
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
      rangeStart: clearRange ? null : (rangeStart ?? this.rangeStart),
      rangeEnd: clearRange ? null : (rangeEnd ?? this.rangeEnd),
      eachAyahRepeat: eachAyahRepeat ?? this.eachAyahRepeat,
      rangeRepeat: rangeRepeat ?? this.rangeRepeat,
      infiniteRepeat: infiniteRepeat ?? this.infiniteRepeat,
      infiniteTarget: infiniteTarget ?? this.infiniteTarget,
      currentAyahPlayCount: currentAyahPlayCount ?? this.currentAyahPlayCount,
      currentRangePass: currentRangePass ?? this.currentRangePass,
    );
  }
}
