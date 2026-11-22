import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/tafsir.dart';
import '../../domain/repositories/tafsir_repository.dart';
import '../datasources/local/tafsir_local_data_source.dart';
import '../datasources/remote/tafsir_remote_data_source.dart';

class TafsirRepositoryImpl implements TafsirRepository {
  TafsirRepositoryImpl({required this.remote, required this.local});

  final TafsirRemoteDataSource remote;
  final TafsirLocalDataSource local;

  CancelToken? _token;
  int? _page;
  Future<List<Tafsir>>? _inFlight;

  @override
  Future<Either<Failure, Tafsir>> getAyahTafsir({
    required int surah,
    required int ayah,
    required int page,
  }) async {
    Future<List<Tafsir>>? future;
    try {
      final cached = local.get(surah, ayah);
      if (cached != null) {
        return Right(Tafsir(surah: surah, ayah: ayah, text: cached));
      }
      if (_page != page) {
        _token?.cancel();
        _page = page;
        _token = CancelToken();
        _inFlight = null;
      }
      final token = _token!;
      future = _inFlight ??= _fetchPage(page, token);
      final items = await future;
      final hit = items
          .where((t) => t.surah == surah && t.ayah == ayah)
          .firstOrNull;
      return Right(hit ?? await _fetchAyah(surah, ayah, token));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(Failure.fromException(e));
    } finally {
      if (future != null && identical(_inFlight, future)) _inFlight = null;
    }
  }

  @override
  void cancelPending() {
    _token?.cancel();
    _token = null;
    _page = null;
    _inFlight = null;
  }

  Future<List<Tafsir>> _fetchPage(int page, CancelToken token) async {
    final items = await remote.getPage(page, cancelToken: token);
    await _store(items);
    return items;
  }

  Future<Tafsir> _fetchAyah(int surah, int ayah, CancelToken token) async {
    final item = await remote.getAyah(surah, ayah, cancelToken: token);
    await _store([item]);
    return item;
  }

  Future<void> _store(List<Tafsir> items) async {
    try {
      await local.putAll(items);
    } on CacheException {
      return;
    }
  }
}
