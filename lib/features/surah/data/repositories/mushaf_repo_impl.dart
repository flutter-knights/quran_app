import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/mushaf_page_entity.dart';
import '../../domain/repositories/mushaf_repo.dart';
import '../datasources/mushaf_local_data_source.dart';

class MushafRepositoryImpl implements MushafRepository {
  MushafRepositoryImpl({required this.dataSource});
  final MushafLocalDataSource dataSource;

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
    try {
      final model = await dataSource.getPage(pageNumber);
      return Right(model);
    } catch (e) {
      return Left(CacheFailure('failed to load page $pageNumber: $e'));
    }
  }
}
