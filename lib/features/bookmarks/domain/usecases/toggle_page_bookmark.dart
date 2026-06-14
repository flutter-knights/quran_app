import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/page_bookmark_repository.dart';

class TogglePageBookmark {
  TogglePageBookmark(this.repository);
  final PageBookmarkRepository repository;

  Future<Either<Failure, bool>> call(int page) => repository.toggle(page);
}
