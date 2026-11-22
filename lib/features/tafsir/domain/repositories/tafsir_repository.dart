import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failure.dart';
import '../entities/tafsir.dart';

abstract class TafsirRepository {
  Future<Either<Failure, Tafsir>> getAyahTafsir({
    required int surah,
    required int ayah,
    required int page,
    required CancelToken cancelToken,
  });
}
