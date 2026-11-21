import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
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
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

MushafCubit _cubit() => MushafCubit(
  args: const MushafArgs(page: 1),
  currentAyahNotifier: _FakeNotifier(),
  pageService: _StubPageService(),
  getMushafPage: GetMushafPage(_StubMushafRepo()),
);

void main() {
  blocTest<MushafCubit, MushafState>(
    'clearSelection clears selectedAyah, leaves playingAyah intact',
    build: () =>
        _cubit()..toggleSelection(const AyahIdentifier(surah: 1, ayah: 1)),
    act: (c) => c.clearSelection(),
    expect: () => [const MushafState(currentPage: 1)],
  );

  blocTest<MushafCubit, MushafState>(
    'clearSelection emits nothing when already null',
    build: _cubit,
    act: (c) => c.clearSelection(),
    expect: () => const <MushafState>[],
  );
}
