import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

void main() {
  test('focus on 2:255 opens page 42 as a jump with the surah opened', () {
    final args = MushafArgs.focus(const AyahIdentifier(surah: 2, ayah: 255));
    expect(args.page, 42);
    expect(args.focusAyah, const AyahIdentifier(surah: 2, ayah: 255));
    expect(args.openedSurah, 2);
    expect(args.origin, MushafOrigin.jump);
  });

  test('focus on a banner (4:0) resolves page 77, not the phantom 76', () {
    final args = MushafArgs.focus(const AyahIdentifier(surah: 4, ayah: 0));
    expect(args.page, 77);
    expect(MushafState.initial(args).selectedAyah, isNull);
  });

  test('the default origin is normal', () {
    expect(const MushafArgs(page: 3).origin, MushafOrigin.normal);
  });
}
