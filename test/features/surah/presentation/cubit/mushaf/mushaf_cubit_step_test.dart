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

class _StubPageService implements QuranPageService {
  @override
  int getPageForAyah(int surah, int ayah) => 50;
  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

AyahIdentifier _id(int s, int a) => AyahIdentifier(surah: s, ayah: a);

MushafCubit _cubit() => MushafCubit(
  args: const MushafArgs(page: 50),
  currentAyahNotifier: ValueNotifier<AyahIdentifier?>(null),
  pageService: _StubPageService(),
  getMushafPage: GetMushafPage(_StubMushafRepo()),
);

void main() {
  test('stepTo on this page only moves the selection', () {
    final cubit = _cubit()..select(_id(3, 7));
    cubit.stepTo(_id(3, 8), page: 50);
    expect(cubit.state.currentPage, 50);
    expect(cubit.state.selectedAyah, _id(3, 8));
    expect(cubit.state.jumpFrom, isNull);
  });

  test(
    'stepTo onto another page turns it and selects the ayah, with no return chip',
    () {
      final cubit = _cubit()..select(_id(3, 9));
      cubit.stepTo(_id(3, 10), page: 51);
      expect(cubit.state.currentPage, 51);
      expect(cubit.state.selectedAyah, _id(3, 10));
      expect(cubit.state.jumpFrom, isNull);
    },
  );

  test('stepTo clears a pending return chip', () {
    final cubit = _cubit()..jumpTo(60);
    expect(cubit.state.jumpFrom, 50);
    cubit.stepTo(_id(3, 10), page: 61);
    expect(cubit.state.currentPage, 61);
    expect(cubit.state.jumpFrom, isNull);
  });

  test('a cross-page step never passes through an empty selection', () async {
    final cubit = _cubit()..select(_id(3, 9));
    final emitted = <MushafState>[];
    final sub = cubit.stream.listen(emitted.add);
    cubit.stepTo(_id(3, 10), page: 51);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emitted, hasLength(1));
    expect(emitted.first.selectedAyah, _id(3, 10));
    expect(emitted.first.currentPage, 51);
  });

  test('stepTo off the playing page stops following playback', () {
    final cubit = _cubit();
    cubit.debugNotifier.value = _id(2, 5);
    expect(cubit.state.followPlayback, isTrue);
    cubit.stepTo(_id(3, 10), page: 51);
    expect(cubit.state.followPlayback, isFalse);
  });

  test('stepTo onto the playing page keeps following playback', () {
    final cubit = _cubit();
    cubit.debugNotifier.value = _id(2, 5);
    cubit.stepTo(_id(2, 6), page: 50);
    expect(cubit.state.followPlayback, isTrue);
  });
}
