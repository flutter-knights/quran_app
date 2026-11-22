import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/tafsir.dart';

abstract class TafsirRepository {
  Future<Either<Failure, Tafsir>> getAyahTafsir({
    required int surah,
    required int ayah,
    required int page,
  });

  void cancelPending();
}
