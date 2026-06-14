import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/page_bookmark_repository.dart';

class GetPageBookmarks {
  GetPageBookmarks(this.repository);
  final PageBookmarkRepository repository;

  Future<Either<Failure, Set<int>>> call() => repository.getAll();
}
