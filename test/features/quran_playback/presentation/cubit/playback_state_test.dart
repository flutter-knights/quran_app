import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
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
}
