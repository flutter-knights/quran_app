import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/reciter.dart';
import '../entities/ayah_identifier.dart';

abstract class QuranPlaybackRepo {
  Stream<AyahIdentifier> get currentAyahStream;
  Stream<void> get onAudioCompleted;
  Future<Either<Failure, String>> prepareAyahAudio({
    required AyahIdentifier ayah,
    required Reciter reciter,
  });
  Future<void> preloadAyahs({
    required List<AyahIdentifier> ayahs,
    required Reciter reciter,
  });
  Future<Either<Failure, void>> playPreparedAudio(String localPath);
  Future<void> pause();
  Future<void> resume();
  void notifyAyahChanged(AyahIdentifier ayah);
  Future<void> stop();
}
