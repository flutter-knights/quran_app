import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith_bookmark.dart';

abstract class HadithBookmarkRepository {
  Future<Either<Failure, Set<HadithBookmark>>> getAll();
  Future<Either<Failure, bool>> toggle(HadithBookmark bookmark);
}
