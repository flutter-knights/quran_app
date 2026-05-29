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

    final decoratedHadiths = page.ahadithList.map((hadith) {
      return hadith.copyWith(
        chapter: chapterLookup[hadith.chapterId],
        arabicNormalized: AhadithHelpers.cleanArabicQuery(hadith.arabicHadith),
      );
    }).toList();

    return Right(page.copyWith(ahadithList: decoratedHadiths));
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
    required int currentHadithNumber,
  }) async {
    final totalPages = HadithPagination.getTotalPages(bookSlug);
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
        if (idx + 1 < hadithList.length) {
          return Right(hadithList[idx + 1]);
        }
        // Current is the last on this page — look at the next page.
        if (page + 1 > totalPages) return const Right(null);
        final nextPage = await getAhadithPage(page + 1, bookSlug);
        return nextPage.fold(
          (f) => Left(f),
          (p) => Right(p.ahadithList.isEmpty ? null : p.ahadithList.first),
        );
      }
      page++;
    }
    return const Right(null);
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
