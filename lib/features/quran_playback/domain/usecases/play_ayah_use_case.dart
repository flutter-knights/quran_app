import 'package:dartz/dartz.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';

import '../../../../core/errors/failure.dart';
import '../../data/repositories/helper/reciter.dart';
import '../entities/ayah_identifier.dart';

class PlayAyahUseCase
    extends UseCase<Either<Failure, void>, PlayAyahUseCaseParams> {
  final QuranPlaybackRepo repo;

  PlayAyahUseCase(this.repo);
  @override
  Future<Either<Failure, void>> call(params) async {
    final prepared = await repo.prepareAyahAudio(
      ayah: params.ayah,
      reciter: params.reciter,
    );

    return prepared.fold(left, (path) async {
      repo.notifyAyahChanged(params.ayah);
      return repo.playPreparedAudio(path);
    });
  }
}

class PlayAyahUseCaseParams {
  AyahIdentifier ayah;
  Reciter reciter;

  PlayAyahUseCaseParams({required this.ayah, required this.reciter});
}
