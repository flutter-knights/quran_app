import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/dio_error_handler.dart';

import '../../domain/entities/ayah_identifier.dart';
import '../../domain/repositories/quran_playback_repo.dart';
import '../datasources/local/quran_playback_local_data_source.dart';
import '../datasources/remote/quran_playback_remote_data_source.dart';
import 'reciter.dart';

class QuranPlaybackRepoImpl extends QuranPlaybackRepo {
  final AudioPlayer player;
  final QuranPlaybackRemoteDataSource remote;
  final QuranPlaybackLocalDataSource local;

  final _ayahController = StreamController<AyahIdentifier>.broadcast();

  QuranPlaybackRepoImpl({
    required this.player,
    required this.remote,
    required this.local,
  });

  @override
  Stream<AyahIdentifier> get currentAyahStream => _ayahController.stream;

  @override
  Stream<void> get onAudioCompleted => player.playerStateStream
      .where((state) => state.processingState == ProcessingState.completed)
      .map((_) => null);
  //TO-DO
  @override
  Future<Either<Failure, String>> prepareAyahAudio({
    required AyahIdentifier ayah,
    required Reciter reciter,
  }) async {
    final url = reciter.getAyahUrl(ayah.surah, ayah.ayah);

    try {
      final cachedPath = local.getCachedLocalPath(url);

      if (cachedPath != null && File(cachedPath).existsSync()) {
        return Right(cachedPath);
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/${reciter.folderName}/${ayah.surah}_${ayah.ayah}.mp3';

      final downloadedPath = await remote.downloadAudio(url, filePath);
      local.cacheAudioMetadata(url, downloadedPath);

      return Right(downloadedPath);
    } on DioException catch (e) {
      return left(DioErrorHandler.handle(e));
    }
    // on CacheException catch (e) {
    //   return left(CacheFailure(e.message));
    // }
    catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> playPreparedAudio(String localPath) async {
    try {
      await player.setFilePath(localPath);
      await player.play();
      return const Right(null);
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<void> stop() => player.stop();

  @override
  void notifyAyahChanged(AyahIdentifier ayah) {
    _ayahController.add(ayah);
  }
}
