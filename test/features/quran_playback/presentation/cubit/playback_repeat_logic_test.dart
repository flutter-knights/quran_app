import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
  final seq = AyahSequenceService();

  PlaybackState base({
    required AyahIdentifier current,
    int eachAyahRepeat = 1,
    int rangeRepeat = 1,
    bool infinite = false,
    RepeatTarget target = RepeatTarget.range,
    int playCount = 1,
    int pass = 1,
    AyahIdentifier? start,
    AyahIdentifier? end,
  }) =>
      PlaybackState(
        currentAyah: current,
        rangeStart: start ?? const AyahIdentifier(surah: 2, ayah: 5),
        rangeEnd: end ?? const AyahIdentifier(surah: 2, ayah: 7),
        eachAyahRepeat: eachAyahRepeat,
        rangeRepeat: rangeRepeat,
        infiniteRepeat: infinite,
        infiniteTarget: target,
        currentAyahPlayCount: playCount,
        currentRangePass: pass,
      );

  group('nextPlaybackStep', () {
    test('repeats the same ayah until eachAyahRepeat reached', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 5),
        eachAyahRepeat: 3,
        playCount: 1,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.repeatAyah);
      expect(step.ayah, const AyahIdentifier(surah: 2, ayah: 5));
      expect(step.nextPlayCount, 2);
    });

    test('advances to next ayah after repeats exhausted', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 5),
        eachAyahRepeat: 2,
        playCount: 2,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.advance);
      expect(step.ayah, const AyahIdentifier(surah: 2, ayah: 6));
      expect(step.nextPlayCount, 1);
    });

    test('at range end with rangeRepeat left, restarts at rangeStart', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 7),
        rangeRepeat: 2,
        pass: 1,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.restartRange);
      expect(step.ayah, const AyahIdentifier(surah: 2, ayah: 5));
      expect(step.nextPass, 2);
    });

    test('at range end with no repeats left, stops', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 7),
        rangeRepeat: 1,
        pass: 1,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.stop);
    });

    test('infinite range never stops at range end', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 7),
        rangeRepeat: 1,
        pass: 9,
        infinite: true,
        target: RepeatTarget.range,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.restartRange);
    });

    test('infinite each-ayah repeats the ayah forever', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 5),
        eachAyahRepeat: 1,
        playCount: 9,
        infinite: true,
        target: RepeatTarget.eachAyah,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.repeatAyah);
    });
  });
}
