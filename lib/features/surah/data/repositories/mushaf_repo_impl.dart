import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/mushaf_page_entity.dart';
import '../../domain/repositories/mushaf_repo.dart';
import '../datasources/mushaf_local_data_source.dart';
import '../datasources/mushaf_page_cache.dart';

typedef MushafPageParser = Future<MushafPageEntity> Function(int pageNumber);

class MushafRepositoryImpl implements MushafRepository {
  MushafRepositoryImpl({
    required this.pageCache,
    MushafPageParser? parser,
  }) : _parser = parser ?? _defaultParser;

  final MushafPageCache pageCache;
  final MushafPageParser _parser;

  static Future<MushafPageEntity> _defaultParser(int pageNumber) {
    return compute(parseMushafPageInIsolate, pageNumber);
  }

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
    final cached = pageCache.get(pageNumber);
    if (cached != null) return Right(cached);
    try {
      final entity = await _parser(pageNumber);
      pageCache.put(pageNumber, entity);
      return Right(entity);
    } catch (e) {
      return Left(CacheFailure('Failed to parse page $pageNumber: $e'));
    }
  }
}
