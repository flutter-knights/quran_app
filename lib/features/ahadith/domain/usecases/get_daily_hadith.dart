import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/daily_hadith_repository.dart';

class GetDailyHadith {
  GetDailyHadith(this._repo);
  final DailyHadithRepository _repo;

  Future<Either<Failure, ({Hadith hadith, String bookSlug})>> call(
    DateTime date,
  ) =>
      _repo.getDailyHadith(date);
}
