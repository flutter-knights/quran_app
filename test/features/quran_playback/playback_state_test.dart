import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
  test('defaults', () {
    const s = PlaybackState();
    expect(s.isPlaying, false);
    expect(s.isPaused, false);
    expect(s.isAutoPlaying, false);
    expect(s.isLoading, false);
    expect(s.error, isNull);
    expect(s.speed, 1.0);
    expect(s.reciter, Reciter.alafasy);
  });

  test('copyWith overrides new fields', () {
    const s = PlaybackState();
    final next = s.copyWith(
      isPaused: true,
      speed: 1.5,
      reciter: Reciter.husary,
    );
    expect(next.isPaused, true);
    expect(next.speed, 1.5);
    expect(next.reciter, Reciter.husary);
  });
}
