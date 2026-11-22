import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
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

class _MapPageService implements QuranPageService {
  @override
  int getPageForAyah(int surah, int ayah) => ayah < 100 ? 50 : 60;
  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

class _CountingRepo implements MushafRepository {
  final ayahs = const [
    AyahBoundEntity(ayah: AyahIdentifier(surah: 2, ayah: 1), lines: []),
  ];
  final loads = <int>[];

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
    loads.add(pageNumber);
    return Right(MushafPageEntity(pageNumber: pageNumber, ayahs: ayahs));
  }
}

MushafCubit _cubit(_FakeNotifier n, {int page = 1, int playingPage = 1}) =>
    MushafCubit(
      args: MushafArgs(page: page),
      currentAyahNotifier: n,
      pageService: _StubPageService(playingPage),
      getMushafPage: GetMushafPage(_StubMushafRepo()),
    );

MushafCubit _tracked({
  int page = 1,
  AyahIdentifier? playing,
  int playingPage = 1,
}) {
  final cubit = _cubit(
    _FakeNotifier()..value = playing,
    page: page,
    playingPage: playingPage,
  );
  addTearDown(cubit.close);
  return cubit;
}

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

    test(
      'stopFollow sets follow false and a second call emits nothing',
      () async {
        final n = _FakeNotifier();
        final cubit = _cubit(n, page: 50, playingPage: 50);
        n.value = a;
        expect(cubit.state.followPlayback, isTrue);
        final states = <bool>[];
        final sub = cubit.stream.listen((s) => states.add(s.followPlayback));
        cubit.stopFollow();
        cubit.stopFollow();
        await pumpEventQueue();
        expect(states, [false]);
        await sub.cancel();
        await cubit.close();
      },
    );

    test('followFrom points the follow target at the range being started', () {
      final n = _FakeNotifier();
      final cubit = _cubit(n, page: 50, playingPage: 50);
      n.value = a;
      cubit.setPage(51, byUser: true);
      expect(cubit.state.followPlayback, isFalse);
      cubit.followFrom(b);
      expect(cubit.state.followPlayback, isTrue);
      expect(cubit.state.playingAyah, a);
      expect(n.value, a);
      cubit.close();
    });

    test('followFrom with nothing playing never writes playingAyah', () {
      final n = _FakeNotifier();
      final cubit = _cubit(n);
      addTearDown(cubit.close);
      cubit.followFrom(b);
      expect(cubit.state.playingAyah, isNull);
      expect(cubit.playingPage, 1);
      cubit.cancelFollowTarget();
      expect(cubit.state.playingAyah, isNull);
      expect(cubit.playingPage, isNull);
    });

    test('the follow target outranks a stale playing ayah until it ends', () {
      final n = _FakeNotifier();
      final cubit = MushafCubit(
        args: const MushafArgs(page: 50),
        currentAyahNotifier: n,
        pageService: _MapPageService(),
        getMushafPage: GetMushafPage(_StubMushafRepo()),
      );
      addTearDown(cubit.close);
      n.value = a;
      const far = AyahIdentifier(surah: 2, ayah: 150);
      cubit.followFrom(far);
      expect(cubit.playingPage, 60);
      n.value = b;
      expect(cubit.playingPage, 50);
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

  group('in-place jumps', () {
    test('jumpTo records where the reader came from and clears selection', () {
      final m = _tracked(page: 50)..toggleSelection(a);
      m.jumpTo(582);
      expect(
        (m.state.currentPage, m.state.jumpFrom, m.state.selectedAyah),
        (582, 50, null),
      );
    });

    test('jumping to the page already showing changes nothing', () {
      final m = _tracked(page: 50)..toggleSelection(a);
      final states = <MushafState>[];
      final sub = m.stream.listen(states.add);
      addTearDown(sub.cancel);
      m.jumpTo(50);
      expect(states, isEmpty);
      expect((m.state.jumpFrom, m.state.selectedAyah), (null, a));
    });

    test('jumpTo with focus selects it on the new page', () {
      const focus = AyahIdentifier(surah: 3, ayah: 6);
      final m = _tracked(page: 2)..jumpTo(50, focus: focus);
      expect(
        (m.state.currentPage, m.state.selectedAyah, m.state.jumpFrom),
        (50, focus, 2),
      );
    });

    test('jumpTo the current page with focus only selects', () {
      const focus = AyahIdentifier(surah: 3, ayah: 6);
      final m = _tracked(page: 50)..jumpTo(100);
      m.jumpTo(100, focus: focus);
      expect(
        (m.state.currentPage, m.state.selectedAyah, m.state.jumpFrom),
        (100, focus, 50),
      );
    });

    test('jumpTo ignores a banner focus', () {
      const banner = AyahIdentifier(surah: 5, ayah: 0);
      final m = _tracked(page: 2)..jumpTo(50, focus: banner);
      expect((m.state.currentPage, m.state.selectedAyah), (50, null));
    });

    test('jumpTo the current page with a banner focus follows the rule', () {
      const banner = AyahIdentifier(surah: 3, ayah: 0);
      final m = _tracked(page: 50);
      final states = <MushafState>[];
      final sub = m.stream.listen(states.add);
      addTearDown(sub.cancel);
      m.jumpTo(50, focus: banner);
      expect(states, isEmpty);
    });

    test('a second jump keeps the first origin', () {
      final m = _tracked(page: 50)
        ..jumpTo(582)
        ..jumpTo(300);
      expect(m.state.jumpFrom, 50);
    });

    test('jumping back to the origin clears jumpFrom', () {
      final m = _tracked(page: 50)
        ..jumpTo(582)
        ..jumpTo(50);
      expect(m.state.jumpFrom, isNull);
    });

    test('a manual turn clears jumpFrom, a follow turn keeps it', () {
      final m = _tracked(page: 50)
        ..jumpTo(582)
        ..setPage(583, byUser: false);
      expect(m.state.jumpFrom, 50);
      m.setPage(584, byUser: true);
      expect(m.state.jumpFrom, isNull);
    });

    test('a follow turn back onto the origin clears jumpFrom', () {
      final m = _tracked(page: 50)
        ..jumpTo(100)
        ..setPage(50, byUser: false);
      expect(m.state.jumpFrom, isNull);
    });

    test('setPage onto the page already showing emits nothing', () {
      final m = _tracked(page: 50)..jumpTo(100);
      final states = <MushafState>[];
      final sub = m.stream.listen(states.add);
      addTearDown(sub.cancel);
      m.setPage(100, byUser: false);
      m.setPage(100, byUser: true);
      expect(states, isEmpty);
    });
  });

  group('boundsFor', () {
    test(
      'returns the loaded ayahs of the current page without a load',
      () async {
        final repo = _CountingRepo();
        final m = MushafCubit(
          args: const MushafArgs(page: 50),
          currentAyahNotifier: _FakeNotifier(),
          pageService: _StubPageService(1),
          getMushafPage: GetMushafPage(repo),
        );
        addTearDown(m.close);
        await Future<void>.delayed(Duration.zero);
        expect(await m.boundsFor(50), repo.ayahs);
        expect(repo.loads, [50]);
        expect(await m.boundsFor(60), repo.ayahs);
        expect(repo.loads, [50, 60]);
      },
    );

    test('loads another page through the use case', () async {
      final m = _tracked(page: 50);
      expect(await m.boundsFor(60), isEmpty);
    });
  });

  group('playingTarget', () {
    test('prefers the follow target and pairs it with its own page', () {
      final m = _tracked(page: 50, playing: a)..followFrom(c);
      expect(m.playingTarget, c);
      m.cancelFollowTarget();
      expect(m.playingTarget, a);
    });
  });

  test('select never deselects', () {
    final m = _tracked(page: 2)
      ..select(c)
      ..select(c);
    expect(m.state.selectedAyah, c);
  });

  test(
    'arriving while the playing ayah is on another page stops following',
    () {
      final m = _tracked(page: 52, playing: a, playingPage: 51);
      expect(m.state.followPlayback, isFalse);
    },
  );

  test('arriving on the playing page keeps following', () {
    final m = _tracked(page: 51, playing: a, playingPage: 51);
    expect(m.state.followPlayback, isTrue);
  });
}
