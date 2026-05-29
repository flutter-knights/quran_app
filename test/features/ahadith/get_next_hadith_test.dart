import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/download_progress.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_previous_hadith.dart';

class _FakeRepo implements AhadithRepository {
  _FakeRepo(this._pages);
  final Map<int, List<Hadith>> _pages; // page -> list

  @override
  Future<Either<Failure, HadithPage>> getAhadithPage(
    int pageNumber,
    String bookSlug,
  ) async {
    final list = _pages[pageNumber] ?? const <Hadith>[];
    return Right(HadithPage(
      ahadithList: list,
      currentPage: pageNumber,
      lastPage: !_pages.containsKey(pageNumber + 1),
    ));
  }

  @override
  Stream<DownloadProgress> downloadAllAhadith(String bookSlug) async* {}

  @override
  List<Chapter> getBookChapters(String bookSlug) => const [];

  @override
  Set<HadithStatus> getBookStatuses(String bookSlug) =>
      const {HadithStatus.sahih, HadithStatus.hasan, HadithStatus.daeef};

  @override
  Future<Either<Failure, Hadith?>> getHadithByNumber({
    required String bookSlug,
    required String hadithNumber,
  }) async =>
      const Right(null);

  @override
  Future<Either<Failure, HadithPage>> getFilteredAhadithPage({
    required int pageNumber,
    required String bookSlug,
    HadithStatus? status,
    int? chapterId,
  }) async =>
      Right(HadithPage(
        ahadithList: const [],
        currentPage: pageNumber,
        lastPage: true,
      ));

  @override
  Future<Either<Failure, Hadith?>> getNextHadith({
    required String bookSlug,
    required String currentHadithNumber,
  }) async {
    int page = 1;
    while (_pages.containsKey(page)) {
      final list = _pages[page]!;
      final idx = list.indexWhere((h) => h.hadithNumber == currentHadithNumber);
      if (idx >= 0) {
        if (idx + 1 < list.length) return Right(list[idx + 1]);
        if (!_pages.containsKey(page + 1)) return const Right(null);
        final next = _pages[page + 1]!;
        return Right(next.isEmpty ? null : next.first);
      }
      page++;
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, Hadith?>> getPreviousHadith({
    required String bookSlug,
    required String currentHadithNumber,
  }) async {
    Hadith? previous;
    int page = 1;
    while (_pages.containsKey(page)) {
      for (final h in _pages[page]!) {
        if (h.hadithNumber == currentHadithNumber) return Right(previous);
        previous = h;
      }
      page++;
    }
    return const Right(null);
  }
}

Hadith _h(int n) => Hadith(
      hadithNumber: '$n',
      englishHadith: '',
      arabicHadith: '',
      englishNarrator: '',
      englishHeader: '',
      arabicHeader: '',
      status: HadithStatus.sahih,
      chapterId: 1,
    );

void main() {
  test('returns next hadith within same page', () async {
    final sut = GetNextHadith(_FakeRepo({
      1: [_h(1), _h(2), _h(3)]
    }));
    final r = await sut(bookSlug: 'b', currentHadithNumber: '1');
    r.fold((l) => fail('expected Right'), (h) => expect(h?.hadithNumber, '2'));
  });

  test('rolls to next page when current is last of its page', () async {
    final sut = GetNextHadith(_FakeRepo({
      1: [_h(1), _h(2)],
      2: [_h(3)]
    }));
    final r = await sut(bookSlug: 'b', currentHadithNumber: '2');
    r.fold((l) => fail('expected Right'), (h) => expect(h?.hadithNumber, '3'));
  });

  test('returns null at the end of the book', () async {
    final sut = GetNextHadith(_FakeRepo({
      1: [_h(1)]
    }));
    final r = await sut(bookSlug: 'b', currentHadithNumber: '1');
    r.fold((l) => fail('expected Right'), (h) => expect(h, isNull));
  });

  test('previous: returns prior hadith within same page', () async {
    final sut = GetPreviousHadith(_FakeRepo({
      1: [_h(1), _h(2), _h(3)]
    }));
    final r = await sut(bookSlug: 'b', currentHadithNumber: '2');
    r.fold((l) => fail('expected Right'), (h) => expect(h?.hadithNumber, '1'));
  });

  test('previous: rolls to prior page when current is first of its page',
      () async {
    final sut = GetPreviousHadith(_FakeRepo({
      1: [_h(1), _h(2)],
      2: [_h(3)]
    }));
    final r = await sut(bookSlug: 'b', currentHadithNumber: '3');
    r.fold((l) => fail('expected Right'), (h) => expect(h?.hadithNumber, '2'));
  });

  test('previous: returns null at the start of the book', () async {
    final sut = GetPreviousHadith(_FakeRepo({
      1: [_h(1), _h(2)]
    }));
    final r = await sut(bookSlug: 'b', currentHadithNumber: '1');
    r.fold((l) => fail('expected Right'), (h) => expect(h, isNull));
  });
}
