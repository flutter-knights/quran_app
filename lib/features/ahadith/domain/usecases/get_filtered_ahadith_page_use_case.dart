import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class GetFilteredAhadithPageUseCase {
  final AhadithRepository ahadithRepository;

  GetFilteredAhadithPageUseCase({required this.ahadithRepository});

  Future<Either<Failure, HadithPage>> call({
    required int pageNumber,
    required String bookSlug,
    HadithStatus? status,
    int? chapterId,
  }) =>
      ahadithRepository.getFilteredAhadithPage(
        pageNumber: pageNumber,
        bookSlug: bookSlug,
        status: status,
        chapterId: chapterId,
      );
}
