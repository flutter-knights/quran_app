import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
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

  test('copyWith keeps error unless clearError', () {
    const s = PlaybackState(error: 'x');
    expect(s.copyWith(isPaused: true).error, 'x');
    expect(s.copyWith(clearError: true).error, isNull);
    expect(s.copyWith(error: 'y').error, 'y');
  });

  test('copyWith clearRequested drops requestedAyah', () {
    const ayah = AyahIdentifier(surah: 2, ayah: 5);
    const s = PlaybackState(requestedAyah: ayah);
    expect(s.copyWith(isPaused: true).requestedAyah, ayah);
    expect(s.copyWith(clearRequested: true).requestedAyah, isNull);
  });

  test('two default states are equal', () {
    expect(const PlaybackState(), const PlaybackState());
    expect(const PlaybackState(error: 'x'), isNot(const PlaybackState()));
  });
}
