import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';

class AhadithSearchRepositoryImpl extends AhadithSearchRepository {
  final AhadithArabicSearchLocalDataSource arabicSearchDataSource;
  final AhadithLocalDataSource ahadithLocalDataSource;
  final AhadithRemoteDataSource ahadithRemoteDataSource;

  AhadithSearchRepositoryImpl({
    required this.arabicSearchDataSource,
    required this.ahadithLocalDataSource,
    required this.ahadithRemoteDataSource,
  });

  @override
  void initializeArabicBookSearch(String bookSlug) {
    arabicSearchDataSource.initBook(bookSlug);
  }

  @override
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    required String bookSlug,
    required bool isDownloaded,
  }) async {
    if (AhadithHelpers.isArabic(query)) {
      final bookNumbers = await arabicSearchDataSource
          .getSearchedHadithsNumbers(query: query);

      if (bookNumbers.isEmpty) return Right([]);

      final localResult = ahadithLocalDataSource.getAhadithByNumbers(
        bookNumbers,
        bookSlug,
      );

      final List<Hadith> combinedResults = localResult.found;

      if (!isDownloaded && localResult.missing.isNotEmpty) {
        try {
          final remoteResults =
              await ahadithRemoteDataSource.getAhadithByNumbers(
            localResult.missing,
            bookSlug,
          );
          combinedResults.addAll(remoteResults);
        } on DioException catch (e) {
          // Surface the failure only when we have nothing to show; otherwise
          // return the local matches we already have.
          if (combinedResults.isEmpty) return left(UnknownFailure(e.toString()));
        }
      }

      return Right(AhadithHelpers.sortHadiths(combinedResults));
    } else {
      if (isDownloaded) {
        final ahadith =
            ahadithLocalDataSource.getSearchedHadiths(query, bookSlug);
        return right(ahadith);
      } else {
        try {
          final ahadith = await ahadithRemoteDataSource.getSearchedHadiths(
            query,
            bookSlug,
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
