import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/repositories/page_bookmark_repository.dart';
import '../datasources/local/page_bookmark_local_data_source.dart';

class PageBookmarkRepositoryImpl implements PageBookmarkRepository {
  PageBookmarkRepositoryImpl({required this.dataSource});
  final PageBookmarkLocalDataSource dataSource;

  @override
  Future<Either<Failure, Set<int>>> getAll() async {
    try {
      return Right(dataSource.getAll());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> toggle(int page) async {
    try {
      return Right(await dataSource.toggle(page));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
