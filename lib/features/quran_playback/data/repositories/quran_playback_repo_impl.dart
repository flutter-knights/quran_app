import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/dio_error_handler.dart';
import '../../domain/entities/ayah_identifier.dart';
import '../../domain/repositories/quran_playback_repo.dart';
import '../datasources/local/quran_playback_local_data_source.dart';
import '../datasources/remote/quran_playback_remote_data_source.dart';
import '../../domain/entities/reciter.dart';

class QuranPlaybackRepoImpl extends QuranPlaybackRepo {
  final AudioPlayer player;
  final QuranPlaybackRemoteDataSource remote;
  final QuranPlaybackLocalDataSource local;
  final Directory dir;

  QuranPlaybackRepoImpl({
    required this.player,
    required this.remote,
    required this.local,
    required this.dir,
  });

  final _ayahController = StreamController<AyahIdentifier>.broadcast();

  // =======================
  // DOWNLOAD MANAGEMENT
  // =======================
  final int _maxConcurrentDownloads = 2;
  int _activeDownloads = 0;
  final Queue<Future<void> Function()> _preloadQueue = Queue();
  final Queue<({String batch, Future<void> Function() run})> _batchQueue =
      Queue();

  /// Prevent duplicate downloads
  final Map<String, Future<String>> _inFlightDownloads = {};

  @override
  Stream<AyahIdentifier> get currentAyahStream => _ayahController.stream;

  @override
  Stream<void> get onAudioCompleted => player.playerStateStream
      .where((s) => s.processingState == ProcessingState.completed)
      .map((_) {});

  @override
  Future<Either<Failure, String>> prepareAyahAudio({
    required AyahIdentifier ayah,
    required Reciter reciter,
  }) async {
    final url = reciter.getAyahUrl(ayah.surah, ayah.ayah);

    try {
      // 1️⃣ Already cached
      final cachedPath = _cachedPath(url, ayah, reciter);
      if (cachedPath != null) return Right(cachedPath);

      // 2️⃣ Download already running
      if (_inFlightDownloads.containsKey(url)) {
        final path = await _inFlightDownloads[url]!;
        return Right(path);
      }

      final filePath = _ayahFilePath(ayah, reciter);

      final file = File(filePath);
      final future = () async {
        await file.parent.create(recursive: true);
        return remote.downloadAudio(url, filePath);
      }();
      _inFlightDownloads[url] = future;

      try {
        final downloadedPath = await future;
        local.cacheAudioMetadata(url, downloadedPath);
        return Right(downloadedPath);
      } catch (_) {
        if (file.existsSync()) file.deleteSync();
        rethrow;
      } finally {
        _inFlightDownloads.remove(url);
      }
    } on DioException catch (e) {
      return left(DioErrorHandler.handle(e));
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> playPreparedAudio(String localPath) async {
    try {
      await player.setFilePath(localPath);
      if (_held) return const Right(null);
      await player.play();
      return const Right(null);
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> playPreparedAudioSequence(
    List<String> localPaths, {
    void Function()? onAdvanceToFinalTrack,
  }) async {
    if (localPaths.isEmpty) {
      return left(UnknownFailure('empty audio sequence'));
    }
    if (localPaths.length == 1) {
      return playPreparedAudio(localPaths.first);
    }
    try {
      await _sequenceIndexSub?.cancel();
      _sequenceIndexSub = null;

      await player.setAudioSources([
        for (final p in localPaths) AudioSource.file(p),
      ]);

      if (onAdvanceToFinalTrack != null) {
        final lastIndex = localPaths.length - 1;
        bool sawNonFinal = false;
        _sequenceIndexSub = player.currentIndexStream.listen((i) {
          if (i == null) return;
          if (i != lastIndex) {
            sawNonFinal = true;
            return;
          }
          if (!sawNonFinal) return;
          onAdvanceToFinalTrack();
          _sequenceIndexSub?.cancel();
          _sequenceIndexSub = null;
        });
      }

      if (_held) return const Right(null);
      await player.play();
      return const Right(null);
    } catch (e) {
      return left(UnknownFailure(e.toString()));
    }
  }

  StreamSubscription<int?>? _sequenceIndexSub;
  var _held = false;

  @override
  void holdPlayback(bool hold) => _held = hold;

  @override
  Future<void> stop() async {
    await _sequenceIndexSub?.cancel();
    _sequenceIndexSub = null;
    await player.stop();
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> resume() => player.play();

  @override
  void notifyAyahChanged(AyahIdentifier ayah) {
    if (!_ayahController.isClosed) {
      _ayahController.add(ayah);
    }
  }

  @override
  Future<void> preloadAyahs({
    required List<AyahIdentifier> ayahs,
    required Reciter reciter,
  }) async {
    for (final ayah in ayahs) {
      final url = reciter.getAyahUrl(ayah.surah, ayah.ayah);

      // ✅ Skip if cached or downloading
      if (local.getCachedLocalPath(url) != null ||
          _inFlightDownloads.containsKey(url)) {
        continue;
      }

      _preloadQueue.add(() async {
        await prepareAyahAudio(ayah: ayah, reciter: reciter);
      });

      unawaited(_runNextDownload());
    }
  }

  Future<void> _runNextDownload() async {
    while (_activeDownloads < _maxConcurrentDownloads) {
      final Future<void> Function() task;
      if (_preloadQueue.isNotEmpty) {
        task = _preloadQueue.removeFirst();
      } else if (_batchQueue.isNotEmpty) {
        task = _batchQueue.removeFirst().run;
      } else {
        return;
      }
      _activeDownloads++;
      unawaited(
        task().whenComplete(() {
          _activeDownloads--;
          unawaited(_runNextDownload());
        }),
      );
    }
  }

  @override
  bool isAyahCached({required AyahIdentifier ayah, required Reciter reciter}) =>
      _cachedPath(reciter.getAyahUrl(ayah.surah, ayah.ayah), ayah, reciter) !=
      null;

  String? _cachedPath(String url, AyahIdentifier ayah, Reciter reciter) {
    final stored = local.getCachedLocalPath(url);
    if (stored == null) return null;
    if (File(stored).existsSync()) return stored;
    final rebased = _ayahFilePath(ayah, reciter);
    if (!File(rebased).existsSync()) return null;
    unawaited(local.cacheAudioMetadata(url, rebased));
    return rebased;
  }

  String _ayahFilePath(AyahIdentifier ayah, Reciter reciter) =>
      '${dir.path}/${reciter.folderName}/${ayah.surah}/${ayah.ayah}.mp3';

  @override
  bool isSurahDownloaded({required int surah, required Reciter reciter}) =>
      local.isSurahDownloaded(reciter.downloadKey(surah));

  @override
  Stream<Either<Failure, double>> downloadSurah({
    required int surah,
    required Reciter reciter,
  }) {
    final controller = StreamController<Either<Failure, double>>();
    final batch = reciter.downloadKey(surah);
    var cancelled = false;

    controller.onCancel = () {
      cancelled = true;
      _batchQueue.removeWhere((t) => t.batch == batch);
    };
    controller.onListen = () {
      final ayat = [
        if (surah != 1 && surah != 9) const AyahIdentifier(surah: 1, ayah: 1),
        for (var a = 1; a <= quran.getVerseCount(surah); a++)
          AyahIdentifier(surah: surah, ayah: a),
      ];
      final missing = [
        for (final a in ayat)
          if (!isAyahCached(ayah: a, reciter: reciter)) a,
      ];
      final total = ayat.length;
      var done = total - missing.length;
      var settled = 0;
      Failure? firstFailure;

      void emit(Either<Failure, double> event) {
        if (!cancelled) controller.add(event);
      }

      Future<void> settle() async {
        if (++settled < missing.length) return;
        if (firstFailure != null) {
          emit(Left(firstFailure!));
          await controller.close();
        }
      }

      Future<void> finish() async {
        try {
          if (!cancelled) await local.markSurahDownloaded(batch);
          emit(const Right(1.0));
        } catch (e) {
          emit(Left(Failure.fromException(e)));
        }
        await controller.close();
      }

      if (missing.isEmpty) {
        unawaited(finish());
        return;
      }
      if (done > 0) emit(Right(done / total));
      for (final a in missing) {
        _batchQueue.add((
          batch: batch,
          run: () async {
            final result = await prepareAyahAudio(ayah: a, reciter: reciter);
            await result.fold(
              (failure) async {
                firstFailure ??= failure;
                await settle();
              },
              (_) async {
                done++;
                if (done == total) return finish();
                emit(Right(done / total));
                await settle();
              },
            );
          },
        ));
      }
      unawaited(_runNextDownload());
    };
    return controller.stream;
  }

  @override
  Future<Either<Failure, void>> deleteSurahDownload({
    required int surah,
    required Reciter reciter,
  }) async {
    try {
      for (var a = surah == 1 ? 2 : 1; a <= quran.getVerseCount(surah); a++) {
        final url = reciter.getAyahUrl(surah, a);
        final paths = {
          ?local.getCachedLocalPath(url),
          _ayahFilePath(AyahIdentifier(surah: surah, ayah: a), reciter),
        };
        for (final path in paths) {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        }
        await local.removeCachedPath(url);
      }
      await local.clearSurahDownloaded(reciter.downloadKey(surah));
      return const Right(null);
    } catch (e) {
      return left(Failure.fromException(e));
    }
  }

  Future<void> dispose() async {
    await _ayahController.close();
    await player.dispose();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);
}
