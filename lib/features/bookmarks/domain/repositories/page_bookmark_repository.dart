import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';

abstract class PageBookmarkRepository {
  Future<Either<Failure, Set<int>>> getAll();
  Future<Either<Failure, bool>> toggle(int page);
}
