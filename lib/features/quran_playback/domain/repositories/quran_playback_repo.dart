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

  /// Plays the given local paths back-to-back as a single logical track so a
  /// single completion event fires after the last file finishes (used to
  /// prepend the basmala before ayah 1 of most surahs). [onAdvanceToFinalTrack]
  /// fires once when the player transitions to the last file in the sequence,
  /// letting callers know basmala has ended and the target verse has begun.
  Future<Either<Failure, void>> playPreparedAudioSequence(
    List<String> localPaths, {
    void Function()? onAdvanceToFinalTrack,
  });
  Future<void> pause();
  Future<void> resume();
  void notifyAyahChanged(AyahIdentifier ayah);
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
}
