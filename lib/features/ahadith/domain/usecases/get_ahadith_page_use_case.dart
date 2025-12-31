
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class GetAhadithPageUseCase
    extends UseCase<Either<Failure, HadithPage>, AhadithPageParams> {
  final AhadithRepository ahadithRepository;

  GetAhadithPageUseCase({required this.ahadithRepository});

  @override
  Future<Either<Failure, HadithPage>> call(AhadithPageParams params) async {
    return await ahadithRepository.getAhadithPage(
      params.pageNumber,
      params.bookSlug,
    );
  }
}

class AhadithPageParams   {
  final int pageNumber;
  final String bookSlug;

  const AhadithPageParams({required this.pageNumber, required this.bookSlug});


}
