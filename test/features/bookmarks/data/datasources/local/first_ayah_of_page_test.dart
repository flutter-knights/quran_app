import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/first_ayah_of_page.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';

class _Repo implements MushafRepository {
  _Repo(this.result);

  final Either<Failure, MushafPageEntity> result;
  final requested = <int>[];

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
    requested.add(pageNumber);
    return result;
  }
}

AyahBoundEntity _bound(int surah, int ayah) => AyahBoundEntity(
  ayah: AyahIdentifier(surah: surah, ayah: ayah),
  lines: const [],
);

void main() {
  test('is the first real ayah, skipping the surah banner', () async {
    final repo = _Repo(
      Right(
        MushafPageEntity(
          pageNumber: 50,
          ayahs: [_bound(3, 0), _bound(3, 1), _bound(3, 2)],
        ),
      ),
    );

    final ayah = await firstAyahOfPage(GetMushafPage(repo))(50);

    expect(ayah, const AyahIdentifier(surah: 3, ayah: 1));
  });

  test('is null for a page with only a banner', () async {
    final repo = _Repo(
      Right(MushafPageEntity(pageNumber: 50, ayahs: [_bound(3, 0)])),
    );

    expect(await firstAyahOfPage(GetMushafPage(repo))(50), isNull);
  });

  test('is null for a page outside 1 to 604 without loading it', () async {
    final repo = _Repo(const Left(CacheFailure('x')));
    final first = firstAyahOfPage(GetMushafPage(repo));

    expect(await first(0), isNull);
    expect(await first(605), isNull);
    expect(repo.requested, isEmpty);
  });

  test('throws a CacheException when a valid page fails to load', () async {
    final repo = _Repo(const Left(CacheFailure('x')));

    expect(
      firstAyahOfPage(GetMushafPage(repo))(50),
      throwsA(isA<CacheException>()),
    );
  });
}
