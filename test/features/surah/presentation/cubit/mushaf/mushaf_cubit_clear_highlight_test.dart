import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

void main() {
  blocTest<MushafCubit, MushafState>(
    'clearHighlight clears highlightedAyah, leaves playingAyah intact',
    build: () =>
        MushafCubit(initialPage: 1, currentAyahNotifier: _FakeNotifier())
          ..toggleHighlight(const AyahIdentifier(surah: 1, ayah: 1)),
    act: (c) => c.clearHighlight(),
    expect: () => [const MushafState(currentPage: 1)],
  );

  blocTest<MushafCubit, MushafState>(
    'clearHighlight emits nothing when already null',
    build: () =>
        MushafCubit(initialPage: 1, currentAyahNotifier: _FakeNotifier()),
    act: (c) => c.clearHighlight(),
    expect: () => const <MushafState>[],
  );
}
