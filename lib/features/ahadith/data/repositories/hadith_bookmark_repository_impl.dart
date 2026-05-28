import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/hadith_bookmark.dart';
import '../../domain/repositories/hadith_bookmark_repository.dart';
import '../datasources/local/hadith_bookmark_local_data_source.dart';

class HadithBookmarkRepositoryImpl implements HadithBookmarkRepository {
  HadithBookmarkRepositoryImpl({required this.dataSource});
  final HadithBookmarkLocalDataSource dataSource;

  @override
  Future<Either<Failure, Set<HadithBookmark>>> getAll() async {
    try {
      return Right(dataSource.getAll());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> toggle(HadithBookmark bookmark) async {
    try {
      return Right(await dataSource.toggle(bookmark));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
