import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

MushafCubit _buildCubit(_FakeNotifier n, {int initialPage = 1}) =>
    MushafCubit(initialPage: initialPage, currentAyahNotifier: n);

void main() {
  group('MushafCubit', () {
    blocTest<MushafCubit, MushafState>(
      'setPage updates currentPage and clears highlight',
      build: () => _buildCubit(_FakeNotifier())
        ..toggleHighlight(const AyahIdentifier(surah: 1, ayah: 1)),
      act: (c) => c.setPage(5),
      expect: () => [
        const MushafState(currentPage: 5),
      ],
    );

    blocTest<MushafCubit, MushafState>(
      'toggleHighlight sets when null',
      build: () => _buildCubit(_FakeNotifier()),
      act: (c) => c.toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      expect: () => [
        const MushafState(
          currentPage: 1,
          highlightedAyah: AyahIdentifier(surah: 2, ayah: 3),
        ),
      ],
    );

    blocTest<MushafCubit, MushafState>(
      'toggleHighlight clears when same key',
      build: () => _buildCubit(_FakeNotifier())
        ..toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      act: (c) => c.toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      expect: () => [
        const MushafState(currentPage: 1),
      ],
    );

    blocTest<MushafCubit, MushafState>(
      'toggleHighlight replaces when different key',
      build: () => _buildCubit(_FakeNotifier())
        ..toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      act: (c) => c.toggleHighlight(const AyahIdentifier(surah: 2, ayah: 4)),
      expect: () => [
        const MushafState(
          currentPage: 1,
          highlightedAyah: AyahIdentifier(surah: 2, ayah: 4),
        ),
      ],
    );

    blocTest<MushafCubit, MushafState>(
      'updates playingAyah when CurrentAyahNotifier emits',
      build: () {
        final n = _FakeNotifier();
        return _buildCubit(n);
      },
      act: (c) {
        c.debugNotifier.value = const AyahIdentifier(surah: 5, ayah: 7);
      },
      expect: () => [
        const MushafState(
          currentPage: 1,
          playingAyah: AyahIdentifier(surah: 5, ayah: 7),
        ),
      ],
    );

    blocTest<MushafCubit, MushafState>(
      'clears playingAyah when CurrentAyahNotifier emits null',
      build: () {
        final n = _FakeNotifier()
          ..value = const AyahIdentifier(surah: 5, ayah: 7);
        return _buildCubit(n);
      },
      act: (c) {
        c.debugNotifier.value = null;
      },
      expect: () => [
        const MushafState(currentPage: 1),
      ],
    );
  });
}
