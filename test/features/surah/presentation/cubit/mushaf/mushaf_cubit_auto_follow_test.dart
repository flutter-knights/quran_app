import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

class _StubPageService implements QuranPageService {
  _StubPageService(this.page);
  final int page;
  @override
  int getPageForAyah(int surah, int ayah) => page;
  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

MushafCubit _cubit(_FakeNotifier n, {int page = 1, int playingPage = 1}) =>
    MushafCubit(
      args: MushafArgs(page: page),
      currentAyahNotifier: n,
      pageService: _StubPageService(playingPage),
      getMushafPage: GetMushafPage(_StubMushafRepo()),
    );

void main() {
  const a = AyahIdentifier(surah: 2, ayah: 1);
  const b = AyahIdentifier(surah: 2, ayah: 2);
  const c = AyahIdentifier(surah: 2, ayah: 5);

  blocTest<MushafCubit, MushafState>(
    'auto-follow: selectedAyah == playingAyah; notifier emits B -> both become B',
    build: () {
      final n = _FakeNotifier();
      final cubit = _cubit(n);
      n.value = a;
      return cubit;
    },
    seed: () =>
        const MushafState(currentPage: 1, selectedAyah: a, playingAyah: a),
    act: (cubit) => cubit.debugNotifier.value = b,
    expect: () => [
      const MushafState(currentPage: 1, selectedAyah: b, playingAyah: b),
    ],
  );

  blocTest<MushafCubit, MushafState>(
    'no auto-follow: selected=C, playing=A; notifier emits B -> selected stays C, playing=B',
    build: () {
      final n = _FakeNotifier();
      final cubit = _cubit(n);
      n.value = a;
      return cubit;
    },
    seed: () =>
        const MushafState(currentPage: 1, selectedAyah: c, playingAyah: a),
    act: (cubit) => cubit.debugNotifier.value = b,
    expect: () => [
      const MushafState(currentPage: 1, selectedAyah: c, playingAyah: b),
    ],
  );

  blocTest<MushafCubit, MushafState>(
    'no auto-follow when selected is null; notifier emits A -> selected stays null',
    build: () => _cubit(_FakeNotifier()),
    act: (cubit) => cubit.debugNotifier.value = a,
    expect: () => [const MushafState(currentPage: 1, playingAyah: a)],
  );

  group('follow playback', () {
    test('setPage(byUser: true) onto the playing page sets follow true', () {
      final n = _FakeNotifier();
      final cubit = _cubit(n, page: 50, playingPage: 50);
      n.value = a;
      cubit.setPage(51, byUser: true);
      expect(cubit.state.followPlayback, isFalse);
      cubit.setPage(50, byUser: true);
      expect(cubit.state.followPlayback, isTrue);
      cubit.close();
    });

    test('resumeFollow sets follow true', () {
      final n = _FakeNotifier();
      final cubit = _cubit(n, page: 50, playingPage: 50);
      n.value = a;
      cubit.setPage(51, byUser: true);
      cubit.resumeFollow();
      expect(cubit.state.followPlayback, isTrue);
      cubit.close();
    });

    test('in-place jump away while playing drops selection and follow', () {
      final n = _FakeNotifier();
      final cubit = _cubit(n, page: 50, playingPage: 50);
      n.value = a;
      cubit.toggleSelection(a);
      cubit.setPage(60, byUser: true);
      expect(cubit.state.selectedAyah, isNull);
      expect(cubit.state.followPlayback, isFalse);
      cubit.close();
    });

    test('notifier null -> A sets follow true', () {
      final n = _FakeNotifier();
      final cubit = _cubit(n, page: 50, playingPage: 50);
      n.value = a;
      cubit.setPage(51, byUser: true);
      n.value = null;
      expect(cubit.state.followPlayback, isFalse);
      n.value = b;
      expect(cubit.state.followPlayback, isTrue);
      cubit.close();
    });

    test('a change from one ayah to another leaves follow alone', () {
      final n = _FakeNotifier();
      final cubit = _cubit(n, page: 50, playingPage: 50);
      n.value = a;
      cubit.setPage(51, byUser: true);
      n.value = b;
      expect(cubit.state.followPlayback, isFalse);
      cubit.close();
    });
  });
}
