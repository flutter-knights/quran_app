import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/mushaf_page_entity.dart';
import '../repositories/mushaf_repo.dart';

class GetMushafPage {
  GetMushafPage(this.repository);

  final MushafRepository repository;

  Future<Either<Failure, MushafPageEntity>> call(int pageNumber) {
    return repository.getPage(pageNumber);
  }
}
