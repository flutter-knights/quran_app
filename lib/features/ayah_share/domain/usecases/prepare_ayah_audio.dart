import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/entities/reciter.dart';
import '../../../quran_playback/domain/repositories/quran_playback_repo.dart';
import '../entities/reel_request.dart';
import '../repositories/reel_repository.dart';

class PrepareAyahAudio {
  PrepareAyahAudio({
    required QuranPlaybackRepo playback,
    required ReelRepository reels,
  }) : _playback = playback,
       _reels = reels;

  final QuranPlaybackRepo _playback;
  final ReelRepository _reels;

  Future<Either<Failure, List<ReelAudio>>> call(
    AyahIdentifier ayah,
    Reciter reciter,
  ) async {
    final hasBasmala = ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9;
    final tracks = <ReelAudio>[];
    for (final part in [
      if (hasBasmala) const AyahIdentifier(surah: 1, ayah: 1),
      ayah,
    ]) {
      final track = await _measured(part, reciter);
      if (track.isLeft()) return track.map((_) => <ReelAudio>[]);
      tracks.add(track.toOption().toNullable()!);
    }
    return Right(tracks);
  }

  Future<Either<Failure, ReelAudio>> _measured(
    AyahIdentifier ayah,
    Reciter reciter,
  ) async {
    final prepared = await _playback.prepareAyahAudio(
      ayah: ayah,
      reciter: reciter,
    );
    return prepared.fold(
      (failure) async => Left(failure),
      (path) async => (await _reels.audioDuration(
        path,
      )).map((duration) => ReelAudio(path: path, duration: duration)),
    );
  }
}
