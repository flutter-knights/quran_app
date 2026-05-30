import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_lookups.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';

class AhadithSearchRepositoryImpl extends AhadithSearchRepository {
  final AhadithArabicSearchLocalDataSource arabicSearchDataSource;
  final AhadithLocalDataSource ahadithLocalDataSource;
  final AhadithRemoteDataSource ahadithRemoteDataSource;
  final Map<String, Map<int, Chapter>> _bookLookupMaps;

  AhadithSearchRepositoryImpl({
    required this.arabicSearchDataSource,
    required this.ahadithLocalDataSource,
    required this.ahadithRemoteDataSource,
    required Map<String, dynamic> allChapters,
  }) : _bookLookupMaps = generateChapterLookups(allChapters);

  @override
  void initializeArabicBookSearch(String bookSlug) {
    arabicSearchDataSource.initBook(bookSlug);
  }

  @override
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    required String bookSlug,
    required bool isDownloaded,
    HadithStatus? status,
    int? chapterId,
  }) async {
    if (AhadithHelpers.isArabic(query)) {
      final bookNumbers = await arabicSearchDataSource.getSearchedHadithsNumbers(
        query: query,
      );

      if (bookNumbers.isEmpty) return Right([]);

      final localResult =
          ahadithLocalDataSource.getAhadithByNumbers(bookNumbers, bookSlug);

      final List<Hadith> combinedResults = localResult.found;

      if (!isDownloaded && localResult.missing.isNotEmpty) {
        try {
          final remoteResults = await ahadithRemoteDataSource
              .getAhadithByNumbers(localResult.missing, bookSlug);
          combinedResults.addAll(remoteResults);
        } on DioException catch (e) {
          if (combinedResults.isEmpty) return left(UnknownFailure(e.toString()));
        }
      }

      // Safety net for any entity whose chapter/status slipped past the index
      // filter (e.g. a remote-fetched missing number).
      final filtered = combinedResults
          .where((h) => status == null || h.status == status)
          .where((h) => chapterId == null || h.chapterId == chapterId)
          .toList();

      return Right(AhadithHelpers.sortHadiths(filtered));
    } else {
      if (isDownloaded) {
        final ahadith = ahadithLocalDataSource.getSearchedHadiths(
          query,
          bookSlug,
          status: status,
          chapterId: chapterId,
        );
        return right(ahadith);
      } else {
        try {
          final chapterNumber = chapterId == null
              ? null
              : _bookLookupMaps[bookSlug]?[chapterId]?.chapterNumber;
          final ahadith = await ahadithRemoteDataSource.getSearchedHadiths(
            query,
            bookSlug,
            status: status == null ? null : hadithStatusApiValue[status],
            chapterNumber: chapterNumber,
          );
          return Right(ahadith);
        } on DioException catch (e) {
          return left(UnknownFailure(e.toString()));
        }
      }
    }
  }

  @override
  void dispose() {
    arabicSearchDataSource.clearCurrentBook();
  }
}
