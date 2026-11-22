import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/tafsir.dart';
import '../repositories/tafsir_repository.dart';

class GetAyahTafsir {
  GetAyahTafsir(this._repository);

  final TafsirRepository _repository;

  Future<Either<Failure, Tafsir>> call({
    required int surah,
    required int ayah,
    required int page,
  }) => _repository.getAyahTafsir(surah: surah, ayah: ayah, page: page);

  void cancel() => _repository.cancelPending();
}
