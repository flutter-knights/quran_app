import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
  test('playedFromNetwork defaults false, counts in equality, copies', () {
    const s = PlaybackState();
    expect(s.playedFromNetwork, isFalse);
    expect(const PlaybackState(playedFromNetwork: true), isNot(s));
    expect(s.copyWith(playedFromNetwork: true).playedFromNetwork, isTrue);
  });

  group('PlaybackState repeat/range defaults', () {
    test('defaults: no range, repeats = 1, not infinite', () {
      const s = PlaybackState();
      expect(s.rangeStart, isNull);
      expect(s.rangeEnd, isNull);
      expect(s.eachAyahRepeat, 1);
      expect(s.rangeRepeat, 1);
      expect(s.infiniteRepeat, false);
      expect(s.infiniteTarget, RepeatTarget.range);
      expect(s.currentAyahPlayCount, 1);
      expect(s.currentRangePass, 1);
    });

    test('copyWith updates and preserves repeat fields', () {
      const s = PlaybackState();
      final n = s.copyWith(
        rangeStart: const AyahIdentifier(surah: 2, ayah: 5),
        rangeEnd: const AyahIdentifier(surah: 2, ayah: 20),
        eachAyahRepeat: 3,
        rangeRepeat: 2,
        infiniteRepeat: true,
        infiniteTarget: RepeatTarget.eachAyah,
        currentAyahPlayCount: 2,
        currentRangePass: 1,
      );
      expect(n.rangeStart, const AyahIdentifier(surah: 2, ayah: 5));
      expect(n.rangeEnd, const AyahIdentifier(surah: 2, ayah: 20));
      expect(n.eachAyahRepeat, 3);
      expect(n.rangeRepeat, 2);
      expect(n.infiniteRepeat, true);
      expect(n.infiniteTarget, RepeatTarget.eachAyah);
      expect(n.currentAyahPlayCount, 2);
      // unrelated field preserved
      expect(n.speed, s.speed);
    });

    test('clearRange wipes range bounds', () {
      const s = PlaybackState(
        rangeStart: AyahIdentifier(surah: 2, ayah: 5),
        rangeEnd: AyahIdentifier(surah: 2, ayah: 20),
      );
      final n = s.copyWith(clearRange: true);
      expect(n.rangeStart, isNull);
      expect(n.rangeEnd, isNull);
    });
  });

  group('PlaybackState skip bounds', () {
    const a = AyahIdentifier(surah: 2, ayah: 5);
    const b = AyahIdentifier(surah: 2, ayah: 6);
    const c = AyahIdentifier(surah: 2, ayah: 7);

    void expectSkips(
      PlaybackState s, {
      required bool next,
      required bool prev,
    }) {
      expect(s.canSkipNext, next);
      expect(s.canSkipPrevious, prev);
    }

    test('idle can skip neither way', () {
      expectSkips(const PlaybackState(), next: false, prev: false);
    });

    test('first ayah with no range cannot skip back', () {
      expectSkips(
        const PlaybackState(currentAyah: AyahIdentifier(surah: 1, ayah: 1)),
        next: true,
        prev: false,
      );
    });

    test('last ayah with no range cannot skip forward', () {
      expectSkips(
        const PlaybackState(currentAyah: AyahIdentifier(surah: 114, ayah: 6)),
        next: false,
        prev: true,
      );
    });

    test('range start cannot skip back', () {
      expectSkips(
        const PlaybackState(currentAyah: a, rangeStart: a, rangeEnd: c),
        next: true,
        prev: false,
      );
    });

    test('range end cannot skip forward', () {
      expectSkips(
        const PlaybackState(currentAyah: c, rangeStart: a, rangeEnd: c),
        next: false,
        prev: true,
      );
    });

    test('inside the range skips both ways', () {
      expectSkips(
        const PlaybackState(currentAyah: b, rangeStart: a, rangeEnd: c),
        next: true,
        prev: true,
      );
    });

    test('a pending request is the skip origin, not the old ayah', () {
      expectSkips(
        const PlaybackState(
          currentAyah: b,
          requestedAyah: a,
          rangeStart: a,
          rangeEnd: c,
        ),
        next: true,
        prev: false,
      );
      expectSkips(
        const PlaybackState(
          currentAyah: b,
          requestedAyah: c,
          rangeStart: a,
          rangeEnd: c,
        ),
        next: false,
        prev: true,
      );
    });

    test('a failed first play can still skip both ways', () {
      expectSkips(
        const PlaybackState(requestedAyah: a, error: 'x'),
        next: true,
        prev: true,
      );
    });
  });
}
