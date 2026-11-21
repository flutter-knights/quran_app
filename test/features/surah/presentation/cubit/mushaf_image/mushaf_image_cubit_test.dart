import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_model.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

class _StubPageService implements QuranPageService {
  @override
  int getPageForAyah(int surah, int ayah) => 1;
  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

class _StubMushafRepo implements MushafRepository {
  final pending = <int, Completer<Either<Failure, MushafPageEntity>>>{};
  bool useJson = false;

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) {
    final pendingPage = pending[pageNumber];
    if (pendingPage != null) return pendingPage.future;
    if (!useJson) {
      return Future.value(
        Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const [])),
      );
    }
    return Future.value(Right(_fromJson(pageNumber)));
  }
}

MushafPageEntity _fromJson(int p) => MushafPageModel.fromJson(
  jsonDecode(
    File(
      'assets/mushaf/bounds/page_${p.toString().padLeft(3, '0')}.json',
    ).readAsStringSync(),
  ),
);

MushafCubit _buildCubit(
  _FakeNotifier n, {
  MushafArgs args = const MushafArgs(page: 1),
  QuranPageService? pageService,
  _StubMushafRepo? repo,
}) => MushafCubit(
  args: args,
  currentAyahNotifier: n,
  pageService: pageService ?? _StubPageService(),
  getMushafPage: GetMushafPage(repo ?? _StubMushafRepo()),
);

void main() {
  const a = AyahIdentifier(surah: 2, ayah: 3);
  const b = AyahIdentifier(surah: 2, ayah: 4);

  group('MushafState.initial', () {
    test('normal origin selects nothing', () {
      final s = MushafState.initial(const MushafArgs(page: 5, focusAyah: a));
      expect(s.selectedAyah, isNull);
    });

    test('jump with focus 2:255 selects it', () {
      const focus = AyahIdentifier(surah: 2, ayah: 255);
      final s = MushafState.initial(
        const MushafArgs(page: 42, focusAyah: focus, origin: MushafOrigin.jump),
      );
      expect(s.selectedAyah, focus);
    });

    test('jump with focus 2:0 selects nothing', () {
      final s = MushafState.initial(
        const MushafArgs(
          page: 2,
          focusAyah: AyahIdentifier(surah: 2, ayah: 0),
          origin: MushafOrigin.jump,
        ),
      );
      expect(s.selectedAyah, isNull);
    });

    test('openedSurah kept and follow starts true', () {
      final s = MushafState.initial(
        const MushafArgs(page: 293, openedSurah: 18),
      );
      expect(s.openedSurah, 18);
      expect(s.followPlayback, isTrue);
    });
  });

  group('MushafArgs.focus', () {
    test('uses the focus page, surah and jump origin', () {
      final args = MushafArgs.focus(const AyahIdentifier(surah: 2, ayah: 255));
      expect(args.page, 42);
      expect(args.openedSurah, 2);
      expect(args.origin, MushafOrigin.jump);
    });
  });

  group('MushafCubit selection', () {
    blocTest<MushafCubit, MushafState>(
      'toggleSelection sets when null',
      build: () => _buildCubit(_FakeNotifier()),
      act: (c) => c.toggleSelection(a),
      expect: () => [const MushafState(currentPage: 1, selectedAyah: a)],
    );

    blocTest<MushafCubit, MushafState>(
      'toggleSelection clears when same key',
      build: () => _buildCubit(_FakeNotifier())..toggleSelection(a),
      act: (c) => c.toggleSelection(a),
      expect: () => [const MushafState(currentPage: 1)],
    );

    blocTest<MushafCubit, MushafState>(
      'toggleSelection replaces when different key',
      build: () => _buildCubit(_FakeNotifier())..toggleSelection(a),
      act: (c) => c.toggleSelection(b),
      expect: () => [const MushafState(currentPage: 1, selectedAyah: b)],
    );

    blocTest<MushafCubit, MushafState>(
      'updates playingAyah when CurrentAyahNotifier emits',
      build: () => _buildCubit(_FakeNotifier()),
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
      expect: () => [const MushafState(currentPage: 1)],
    );
  });

  group('MushafCubit.setPage', () {
    test('byUser false keeps selection and follow', () {
      final c = _buildCubit(_FakeNotifier())..toggleSelection(a);
      c.setPage(5, byUser: false);
      expect(c.state.currentPage, 5);
      expect(c.state.selectedAyah, a);
      expect(c.state.followPlayback, isTrue);
      c.close();
    });

    test(
      'byUser true away from the playing page drops selection and follow',
      () {
        final n = _FakeNotifier()
          ..value = const AyahIdentifier(surah: 2, ayah: 1);
        final c = _buildCubit(n)..toggleSelection(b);
        c.setPage(5, byUser: true);
        expect(c.state.currentPage, 5);
        expect(c.state.selectedAyah, isNull);
        expect(c.state.followPlayback, isFalse);
        c.close();
      },
    );

    test('byUser true with nothing playing leaves follow alone', () {
      final c = _buildCubit(_FakeNotifier());
      c.setPage(5, byUser: true);
      expect(c.state.followPlayback, isTrue);
      c.close();
    });
  });

  group('MushafCubit pageAyahs', () {
    test('loads on init and on setPage', () async {
      final repo = _StubMushafRepo()..useJson = true;
      final c = _buildCubit(
        _FakeNotifier(),
        args: const MushafArgs(page: 5),
        repo: repo,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        c.state.pageAyahs.map((e) => e.ayah),
        _fromJson(5).ayahs.map((e) => e.ayah),
      );
      c.setPage(6, byUser: true);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.pageAyahs.first.ayah, _fromJson(6).ayahs.first.ayah);
      c.close();
    });

    test('setPage clears pageAyahs until the load completes', () async {
      final repo = _StubMushafRepo()..useJson = true;
      final c = _buildCubit(
        _FakeNotifier(),
        args: const MushafArgs(page: 5),
        repo: repo,
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.state.pageAyahs, isNotEmpty);
      final completer = Completer<Either<Failure, MushafPageEntity>>();
      repo.pending[6] = completer;
      c.setPage(6, byUser: true);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.pageAyahs, isEmpty);
      completer.complete(Right(_fromJson(6)));
      await Future<void>.delayed(Duration.zero);
      expect(c.state.pageAyahs.first.ayah, _fromJson(6).ayahs.first.ayah);
      c.close();
    });

    test(
      'a late result for an older page never overwrites the newer one',
      () async {
        final repo = _StubMushafRepo();
        final c5 = Completer<Either<Failure, MushafPageEntity>>();
        final c6 = Completer<Either<Failure, MushafPageEntity>>();
        repo.pending[5] = c5;
        repo.pending[6] = c6;
        final c = _buildCubit(_FakeNotifier(), repo: repo);
        c.setPage(5, byUser: true);
        c.setPage(6, byUser: true);
        c6.complete(Right(_fromJson(6)));
        await Future<void>.delayed(Duration.zero);
        c5.complete(Right(_fromJson(5)));
        await Future<void>.delayed(Duration.zero);
        expect(c.state.currentPage, 6);
        expect(c.state.pageAyahs.first.ayah, _fromJson(6).ayahs.first.ayah);
        c.close();
      },
    );

    test('runningSurah on p.293 with openedSurah 18 is 18', () async {
      final repo = _StubMushafRepo()..useJson = true;
      final c = _buildCubit(
        _FakeNotifier(),
        args: const MushafArgs(page: 293, openedSurah: 18),
        repo: repo,
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.state.runningSurah, 18);
      c.close();
    });
  });

  group('MushafCubit.playingPage', () {
    test('is null with nothing playing', () {
      final c = _buildCubit(_FakeNotifier());
      expect(c.playingPage, isNull);
      c.close();
    });

    test('maps the banner (4,0) to page 77', () {
      final n = _FakeNotifier()
        ..value = const AyahIdentifier(surah: 4, ayah: 0);
      final c = _buildCubit(n, pageService: QuranPageServiceImpl());
      expect(c.playingPage, 77);
      c.close();
    });
  });
}
