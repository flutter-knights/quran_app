import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../datasources/local/bookmark_local_data_source.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  BookmarkRepositoryImpl({required this.dataSource});
  final BookmarkLocalDataSource dataSource;

  @override
  Future<Either<Failure, Set<AyahIdentifier>>> getAll() async {
    try {
      return Right(dataSource.getAll());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> toggle(AyahIdentifier ayah) async {
    try {
      final added =
          await dataSource.toggle(surah: ayah.surah, ayah: ayah.ayah);
      return Right(added);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> isBookmarked(AyahIdentifier ayah) async {
    try {
      return Right(dataSource.getAll().contains(ayah));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
