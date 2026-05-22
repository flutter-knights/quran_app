import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

void main() {
  const a = AyahIdentifier(surah: 2, ayah: 1);
  const b = AyahIdentifier(surah: 2, ayah: 2);
  const c = AyahIdentifier(surah: 2, ayah: 5);

  blocTest<MushafCubit, MushafState>(
    'auto-follow: highlightedAyah == playingAyah; notifier emits B -> both become B',
    build: () {
      final n = _FakeNotifier();
      final cubit = MushafCubit(initialPage: 1, currentAyahNotifier: n);
      n.value = a;
      return cubit;
    },
    seed: () =>
        const MushafState(currentPage: 1, highlightedAyah: a, playingAyah: a),
    act: (cubit) => cubit.debugNotifier.value = b,
    expect: () => [
      const MushafState(currentPage: 1, highlightedAyah: b, playingAyah: b),
    ],
  );

  blocTest<MushafCubit, MushafState>(
    'no auto-follow: highlighted=C, playing=A; notifier emits B -> highlighted stays C, playing=B',
    build: () {
      final n = _FakeNotifier();
      final cubit = MushafCubit(initialPage: 1, currentAyahNotifier: n);
      n.value = a;
      return cubit;
    },
    seed: () =>
        const MushafState(currentPage: 1, highlightedAyah: c, playingAyah: a),
    act: (cubit) => cubit.debugNotifier.value = b,
    expect: () => [
      const MushafState(currentPage: 1, highlightedAyah: c, playingAyah: b),
    ],
  );

  blocTest<MushafCubit, MushafState>(
    'no auto-follow when highlighted is null; notifier emits A -> highlighted stays null',
    build: () =>
        MushafCubit(initialPage: 1, currentAyahNotifier: _FakeNotifier()),
    act: (cubit) => cubit.debugNotifier.value = a,
    expect: () => [const MushafState(currentPage: 1, playingAyah: a)],
  );
}
