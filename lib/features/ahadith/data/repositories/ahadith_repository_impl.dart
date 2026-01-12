import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class AhadithRepositoryImpl implements AhadithRepository {
  final AhadithLocalDataSource ahadithLocalDataSource;
  final AhadithRemoteDataSource ahadithRemoteDataSource;
  final Map<String, dynamic> allChapters;

  AhadithRepositoryImpl({
    required this.ahadithLocalDataSource,
    required this.ahadithRemoteDataSource,
    required this.allChapters,
  });

  @override
  Future<Either<Failure, HadithPage>> getAhadithPage(
    int pageNumber,
    String bookSlug,
  ) async {
    final List<dynamic> bookChaptersRaw = allChapters[bookSlug] ?? [];
    final Map<int, Chapter> chapterLookup = {
      for (var item in bookChaptersRaw)
        item['id']: Chapter(
          id: item['id'],
          chapterNumber: item['chapterNumber'],
          chapterArabic: item['chapterArabic'],
          chapterEnglish: item['chapterEnglish'],
        ),
    };

    HadithPage? pageToDecorate;

    pageToDecorate = ahadithLocalDataSource.getCachedPage(pageNumber, bookSlug);

    if (pageToDecorate == null) {
      try {
        pageToDecorate = await ahadithRemoteDataSource.getAhadithPage(
          pageNumber,
          bookSlug,
        );

        ahadithLocalDataSource.cachePage(pageToDecorate, pageNumber, bookSlug);
      } on DioException catch (e) {
        return left(UnknownFailure(e.toString()));
      }
    }

    final decoratedHadiths = pageToDecorate.ahadithList.map((hadith) {
      return hadith.copyWith(chapter: chapterLookup[hadith.chapterId]);
    }).toList();

    return Right(pageToDecorate.copyWith(ahadithList: decoratedHadiths));
  }
}
