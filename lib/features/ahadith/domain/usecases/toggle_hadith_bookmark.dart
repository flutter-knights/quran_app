import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith_bookmark.dart';
import '../repositories/hadith_bookmark_repository.dart';

class ToggleHadithBookmark {
  ToggleHadithBookmark(this._repo);
  final HadithBookmarkRepository _repo;

  Future<Either<Failure, bool>> call(HadithBookmark bookmark) =>
      _repo.toggle(bookmark);
}
