import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/download_progress.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class AhadithRepositoryImpl implements AhadithRepository {
  final AhadithLocalDataSource ahadithLocalDataSource;
  final AhadithRemoteDataSource ahadithRemoteDataSource;
  final Map<String, Map<int, Chapter>> _bookLookupMaps;

  AhadithRepositoryImpl({
    required this.ahadithLocalDataSource,
    required this.ahadithRemoteDataSource,
    required Map<String, dynamic> allChapters,
  }) : _bookLookupMaps = _generateLookups(allChapters);

  @override
  Future<Either<Failure, HadithPage>> getAhadithPage(
    int pageNumber,
    String bookSlug,
  ) async {
    final chapterLookup = _bookLookupMaps[bookSlug] ?? {};

    HadithPage? page = ahadithLocalDataSource.getCachedPage(
      pageNumber,
      bookSlug,
    );

    if (page == null) {
      try {
        page = await ahadithRemoteDataSource.getAhadithPage(
          pageNumber,
          bookSlug,
        );
        ahadithLocalDataSource.cachePage(page, pageNumber, bookSlug);
      } on DioException catch (e) {
        return left(UnknownFailure(e.toString()));
      }
    }

    return Right(_decoratePage(page, chapterLookup));
  }

  static const Map<HadithStatus, String> _statusApiValue = {
    HadithStatus.sahih: 'Sahih',
    HadithStatus.hasan: 'Hasan',
    HadithStatus.daeef: 'Da`eef',
  };

  @override
  Future<Either<Failure, HadithPage>> getFilteredAhadithPage({
    required int pageNumber,
    required String bookSlug,
    HadithStatus? status,
    int? chapterId,
  }) async {
    final chapterLookup = _bookLookupMaps[bookSlug] ?? {};
    final chapterNumber =
        chapterId == null ? null : chapterLookup[chapterId]?.chapterNumber;
    try {
      final page = await ahadithRemoteDataSource.getFilteredAhadithPage(
        pageNumber,
        bookSlug,
        status: status == null ? null : _statusApiValue[status],
        chapterNumber: chapterNumber,
      );
      return Right(_decoratePage(page, chapterLookup));
    } on DioException catch (e) {
      // The API answers a filter with no matches (e.g. Hasan in an all-Sahih
      // book) with 404 — that's an empty result, not an error.
      if (e.response?.statusCode == 404) {
        return Right(
          HadithPage(ahadithList: const [], currentPage: pageNumber, lastPage: true),
        );
      }
      return left(UnknownFailure(e.toString()));
    }
  }

  HadithPage _decoratePage(HadithPage page, Map<int, Chapter> chapterLookup) {
    final decorated = page.ahadithList
        .map(
          (hadith) => hadith.copyWith(
            chapter: chapterLookup[hadith.chapterId],
            arabicNormalized:
                AhadithHelpers.cleanArabicQuery(hadith.arabicHadith),
          ),
        )
        .toList();
    return page.copyWith(ahadithList: decorated);
  }

  @override
  Stream<DownloadProgress> downloadAllAhadith(String bookSlug) async* {
    int progress = 0;
    int pageNumber = 1;
    int trials = 3;
    int totalPages = HadithPagination.getTotalPages(bookSlug);
    while (true) {
      final potentiallyCachedPage = ahadithLocalDataSource.getCachedPage(
        pageNumber,
        bookSlug,
      );
      if (potentiallyCachedPage != null) {
        trials = 3;
        pageNumber++;
        if (pageNumber > totalPages) return;
        progress = ((pageNumber / totalPages) * 100).toInt();
        yield DownloadProgress(bookSlug: bookSlug, progress: progress);
        continue;
      }
      try {
        HadithPage page = await ahadithRemoteDataSource.getAhadithPage(
          pageNumber,
          bookSlug,
        );
        ahadithLocalDataSource.cachePage(page, pageNumber, bookSlug);
        progress = ((pageNumber / totalPages) * 100).toInt();
        yield DownloadProgress(bookSlug: bookSlug, progress: progress);

        if (page.lastPage) {
          yield DownloadProgress(bookSlug: bookSlug, progress: 100);
          return;
        }
        trials = 3;
        pageNumber++;
      } catch (e) {
        trials--;
        if (trials > 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        throw Exception('can\'n download book');
      }
    }
  }

  @override
  Future<Either<Failure, Hadith?>> getNextHadith({
    required String bookSlug,
    required String currentHadithNumber,
  }) async {
    final totalPages = HadithPagination.getTotalPages(bookSlug);

    // Fast path: hadith numbers are roughly sequential, so the current hadith
    // is near page ceil(number / kPageLimit). This avoids scanning (and, for
    // an uncached book, re-fetching) every page from 1 on each navigation.
    final located =
        await _locateByEstimate(bookSlug, currentHadithNumber, totalPages);
    if (located != null) {
      return _nextFrom(
        located.page,
        located.index,
        located.list,
        bookSlug,
        totalPages,
      );
    }

    // Fallback: sparse/non-sequential numbering — scan from the start.
    int page = 1;
    while (page <= totalPages) {
      final pageResult = await getAhadithPage(page, bookSlug);
      final hadithList =
          pageResult.fold((_) => <Hadith>[], (p) => p.ahadithList);
      if (hadithList.isEmpty) return const Right(null);
      final idx = hadithList.indexWhere(
        (h) => h.hadithNumber == currentHadithNumber,
      );
      if (idx >= 0) {
        return _nextFrom(page, idx, hadithList, bookSlug, totalPages);
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
    final totalPages = HadithPagination.getTotalPages(bookSlug);

    final located =
        await _locateByEstimate(bookSlug, currentHadithNumber, totalPages);
    if (located != null) {
      return _prevFrom(located.page, located.index, located.list, bookSlug);
    }

    int page = 1;
    while (page <= totalPages) {
      final pageResult = await getAhadithPage(page, bookSlug);
      final hadithList =
          pageResult.fold((_) => <Hadith>[], (p) => p.ahadithList);
      if (hadithList.isEmpty) return const Right(null);
      final idx = hadithList.indexWhere(
        (h) => h.hadithNumber == currentHadithNumber,
      );
      if (idx >= 0) return _prevFrom(page, idx, hadithList, bookSlug);
      page++;
    }
    return const Right(null);
  }

  /// Locates [currentHadithNumber] by probing the estimated page (and its
  /// neighbors). Returns null when the estimate misses, so callers fall back to
  /// a full scan.
  Future<({int page, int index, List<Hadith> list})?> _locateByEstimate(
    String bookSlug,
    String currentHadithNumber,
    int totalPages,
  ) async {
    final num = int.tryParse(currentHadithNumber.split(',').first);
    if (num == null) return null;
    final estimate = (num / kPageLimit).ceil();
    for (int p = estimate - 1; p <= estimate + 1; p++) {
      if (p < 1 || p > totalPages) continue;
      final result = await getAhadithPage(p, bookSlug);
      final list = result.fold((_) => <Hadith>[], (page) => page.ahadithList);
      final idx =
          list.indexWhere((h) => h.hadithNumber == currentHadithNumber);
      if (idx >= 0) return (page: p, index: idx, list: list);
    }
    return null;
  }

  Future<Either<Failure, Hadith?>> _nextFrom(
    int page,
    int index,
    List<Hadith> list,
    String bookSlug,
    int totalPages,
  ) async {
    if (index + 1 < list.length) return Right(list[index + 1]);
    if (page + 1 > totalPages) return const Right(null);
    final nextPage = await getAhadithPage(page + 1, bookSlug);
    return nextPage.fold(
      (f) => Left(f),
      (p) => Right(p.ahadithList.isEmpty ? null : p.ahadithList.first),
    );
  }

  Future<Either<Failure, Hadith?>> _prevFrom(
    int page,
    int index,
    List<Hadith> list,
    String bookSlug,
  ) async {
    if (index - 1 >= 0) return Right(list[index - 1]);
    if (page - 1 < 1) return const Right(null);
    final prevPage = await getAhadithPage(page - 1, bookSlug);
    return prevPage.fold(
      (f) => Left(f),
      (p) => Right(p.ahadithList.isEmpty ? null : p.ahadithList.last),
    );
  }

  /// Grades present per book, verified against the API. Unknown books fall back
  /// to offering all three.
  static const Map<String, Set<HadithStatus>> _bookStatuses = {
    'sahih-bukhari': {HadithStatus.sahih},
    'sahih-muslim': {HadithStatus.sahih},
    'al-tirmidhi': {HadithStatus.sahih, HadithStatus.daeef},
    'abu-dawood': {HadithStatus.sahih, HadithStatus.hasan, HadithStatus.daeef},
    'ibn-e-majah': {HadithStatus.sahih, HadithStatus.daeef},
    'sunan-nasai': {HadithStatus.sahih, HadithStatus.hasan, HadithStatus.daeef},
    'mishkat': {HadithStatus.sahih},
  };

  @override
  Set<HadithStatus> getBookStatuses(String bookSlug) =>
      _bookStatuses[bookSlug] ??
      const {HadithStatus.sahih, HadithStatus.hasan, HadithStatus.daeef};

  @override
  Future<Either<Failure, Hadith?>> getHadithByNumber({
    required String bookSlug,
    required String hadithNumber,
  }) async {
    final chapterLookup = _bookLookupMaps[bookSlug] ?? {};
    try {
      final results = await ahadithRemoteDataSource.getAhadithByNumbers(
        [hadithNumber],
        bookSlug,
      );
      if (results.isEmpty) return const Right(null);
      final h = results.first;
      return Right(
        h.copyWith(
          chapter: chapterLookup[h.chapterId],
          arabicNormalized: AhadithHelpers.cleanArabicQuery(h.arabicHadith),
        ),
      );
    } on DioException catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  List<Chapter> getBookChapters(String bookSlug) {
    final lookup = _bookLookupMaps[bookSlug];
    if (lookup == null) return const [];
    final chapters = lookup.values.toList()
      ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    return chapters;
  }

  static Map<String, Map<int, Chapter>> _generateLookups(
    Map<String, dynamic> raw,
  ) {
    return raw.map((bookSlug, chaptersList) {
      final list = chaptersList as List<dynamic>;
      final lookup = {
        for (var item in list)
          item['id'] as int: Chapter(
            id: item['id'],
            chapterNumber: item['chapterNumber'],
            chapterArabic: item['chapterArabic'],
            chapterEnglish: item['chapterEnglish'],
          ),
      };
      return MapEntry(bookSlug, lookup);
    });
  }
}
