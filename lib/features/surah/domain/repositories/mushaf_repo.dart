import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/mushaf_page_entity.dart';

abstract class MushafRepository {
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber);
}
