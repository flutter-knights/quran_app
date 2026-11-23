import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/domain/usecases/get_share_card_content.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';

import '../../../surah/mushaf_bounds_fixture.dart';

class _FakeMushafRepo implements MushafRepository {
  _FakeMushafRepo({this.failure, this.empty = false});

  final Failure? failure;
  final bool empty;
  final pages = <int>[];

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
    pages.add(pageNumber);
    final failure = this.failure;
    if (failure != null) return Left(failure);
    return Right(
      MushafPageEntity(
        pageNumber: pageNumber,
        ayahs: empty ? const [] : boundsOf(pageNumber),
      ),
    );
  }
}

GetShareCardContent _build(_FakeMushafRepo repo) => GetShareCardContent(
  getMushafPage: GetMushafPage(repo),
  pageService: QuranPageServiceImpl(),
);

void main() {
  test('returns the ayah page and the surah start page', () async {
    final repo = _FakeMushafRepo();

    final result = await _build(repo)(const AyahIdentifier(surah: 6, ayah: 31));

    final content = result.getOrElse(() => throw StateError('left'));
    expect(content.page, 131);
    expect(content.startPage, 128);
    expect(content.pageBounds, isNotEmpty);
    expect(content.startPageBounds, isNotEmpty);
    expect(repo.pages, [131, 128]);
  });

  test('fetches a page once when the ayah is on the start page', () async {
    final repo = _FakeMushafRepo();

    final result = await _build(repo)(
      const AyahIdentifier(surah: 112, ayah: 1),
    );

    final content = result.getOrElse(() => throw StateError('left'));
    expect(repo.pages, [604]);
    expect(identical(content.startPageBounds, content.pageBounds), isTrue);
  });

  test('page 1 works', () async {
    final result = await _build(_FakeMushafRepo())(
      const AyahIdentifier(surah: 1, ayah: 1),
    );

    final content = result.getOrElse(() => throw StateError('left'));
    expect(content.page, 1);
    expect(content.startPage, 1);
  });

  test('an ayah missing from its bounds is a failure', () async {
    final result = await _build(_FakeMushafRepo(empty: true))(
      const AyahIdentifier(surah: 2, ayah: 3),
    );

    expect(result.isLeft(), isTrue);
  });

  test('a bounds failure is returned as is', () async {
    const failure = CacheFailure('x');

    final result = await _build(_FakeMushafRepo(failure: failure))(
      const AyahIdentifier(surah: 2, ayah: 3),
    );

    expect(result.fold((f) => identical(f, failure), (_) => false), isTrue);
  });
}
