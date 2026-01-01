import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class AhadithRepositoryImpl implements AhadithRepository {
  final AhadithLocalDataSource ahadithLocalDataSource;
  final AhadithRemoteDataSource ahadithRemoteDataSource;

  AhadithRepositoryImpl({
    required this.ahadithLocalDataSource,
    required this.ahadithRemoteDataSource,
  });

  @override
  Future<Either<Failure, HadithPage>> getAhadithPage(
    int pageNumber,
    String bookSlug,
  ) async {
    final HadithPage? ahadithCachedPage = ahadithLocalDataSource.getCachedPage(
      pageNumber,
      bookSlug,
    );
    if (ahadithCachedPage != null) {
      return Right(ahadithCachedPage);
    }
    try {
      final HadithPage ahadithPage = await ahadithRemoteDataSource
          .getAhadithPage(pageNumber, bookSlug);
          ahadithLocalDataSource.cachePage(
        ahadithPage,
        pageNumber,
        bookSlug,
      );
      return Right(ahadithPage);
    } on DioException catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }
}
