import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith_bookmark.dart';
import '../repositories/hadith_bookmark_repository.dart';

class GetHadithBookmarks {
  GetHadithBookmarks(this._repo);
  final HadithBookmarkRepository _repo;

  Future<Either<Failure, Set<HadithBookmark>>> call() => _repo.getAll();
}
