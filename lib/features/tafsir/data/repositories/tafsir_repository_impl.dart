import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/tafsir.dart';
import '../../domain/repositories/tafsir_repository.dart';
import '../datasources/local/tafsir_local_data_source.dart';
import '../datasources/remote/tafsir_remote_data_source.dart';
import '../models/tafsir_model.dart';

class TafsirRepositoryImpl implements TafsirRepository {
  TafsirRepositoryImpl({required this.remote, required this.local});

  final TafsirRemoteDataSource remote;
  final TafsirLocalDataSource local;

  final _inFlight = Expando<Future<List<TafsirModel>>>();
  final _fetched = Expando<int>();

  @override
  Future<Either<Failure, Tafsir>> getAyahTafsir({
    required int surah,
    required int ayah,
    required int page,
    required CancelToken cancelToken,
  }) async {
    Future<List<TafsirModel>>? future;
    try {
      final cached = local.get(surah, ayah);
      if (cached != null) {
        return Right(Tafsir(surah: surah, ayah: ayah, text: cached));
      }
      TafsirModel? hit;
      if (_fetched[cancelToken] != page) {
        future = _inFlight[cancelToken] ??= _fetchPage(page, cancelToken);
        final items = await future;
        _fetched[cancelToken] = page;
        hit = items
            .where((t) => t.surah == surah && t.ayah == ayah)
            .firstOrNull;
      }
      return Right(
        (hit ?? await _fetchAyah(surah, ayah, cancelToken)).toEntity(),
      );
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(Failure.fromException(e));
    } finally {
      if (future != null && identical(_inFlight[cancelToken], future)) {
        _inFlight[cancelToken] = null;
      }
    }
  }

  Future<List<TafsirModel>> _fetchPage(int page, CancelToken token) async {
    final items = await remote.getPage(page, cancelToken: token);
    await _store(items);
    return items;
  }

  Future<TafsirModel> _fetchAyah(int surah, int ayah, CancelToken token) async {
    final item = await remote.getAyah(surah, ayah, cancelToken: token);
    await _store([item]);
    return item;
  }

  Future<void> _store(List<TafsirModel> items) async {
    try {
      await local.putAll([for (final m in items) m.toEntity()]);
    } on CacheException {
      return;
    }
  }
}
