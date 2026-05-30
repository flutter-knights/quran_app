import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

abstract class AhadithSearchRepository {
  void initializeArabicBookSearch(String bookSlug);
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    required String bookSlug,
    required bool isDownloaded,
  });
  void dispose();
}
