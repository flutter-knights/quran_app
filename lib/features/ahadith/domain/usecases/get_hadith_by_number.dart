import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith.dart';
import '../repositories/ahadith_repository.dart';

class GetHadithByNumber {
  GetHadithByNumber(this._repo);
  final AhadithRepository _repo;

  Future<Either<Failure, Hadith?>> call({
    required String bookSlug,
    required String hadithNumber,
  }) =>
      _repo.getHadithByNumber(bookSlug: bookSlug, hadithNumber: hadithNumber);
}
