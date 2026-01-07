import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../data/repositories/reciter.dart';
import '../entities/ayah_identifier.dart';

abstract class QuranPlaybackRepo {
  Stream<AyahIdentifier> get currentAyahStream;

  Future<Either<Failure, String>> prepareAyahAudio({
    required AyahIdentifier ayah,
    required Reciter reciter,
  });

  Future<Either<Failure, void>> playPreparedAudio(String localPath);
  void notifyAyahChanged(AyahIdentifier ayah);
  Future<void> stop();
}
