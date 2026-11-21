import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/data/datasources/local/quran_playback_local_data_source.dart';
import 'package:quran_app/features/quran_playback/data/datasources/remote/quran_playback_remote_data_source.dart';
import 'package:quran_app/features/quran_playback/data/repositories/quran_playback_repo_impl.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';

class _MockPlayer extends Mock implements AudioPlayer {}

class _MockRemote extends Mock implements QuranPlaybackRemoteDataSource {}

class _MockLocal extends Mock implements QuranPlaybackLocalDataSource {}

void main() {
  const ayah = AyahIdentifier(surah: 2, ayah: 5);
  const reciter = Reciter.alafasy;

  late Directory dir;
  late _MockRemote remote;
  late _MockLocal local;
  late QuranPlaybackRepoImpl repo;
  late String savePath;
  late Map<String, String> cache;
  late Map<String, bool> records;

  String pathOf(AyahIdentifier a, [Reciter r = reciter]) =>
      '${dir.path}/${r.folderName}/${a.surah}/${a.ayah}.mp3';

  void seed(AyahIdentifier a) {
    final path = pathOf(a);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync([0]);
    cache[reciter.getAyahUrl(a.surah, a.ayah)] = path;
  }

  Future<String> writeFile(String path) async {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync([0]);
    return path;
  }

  Future<List<Either<Failure, double>>> download(int surah) =>
      repo.downloadSurah(surah: surah, reciter: reciter).toList();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('playback_repo_test');
    remote = _MockRemote();
    local = _MockLocal();
    cache = {};
    records = {};
    when(
      () => local.getCachedLocalPath(any()),
    ).thenAnswer((inv) => cache[inv.positionalArguments[0] as String]);
    when(() => local.cacheAudioMetadata(any(), any())).thenAnswer((inv) async {
      cache[inv.positionalArguments[0] as String] =
          inv.positionalArguments[1] as String;
    });
    when(() => local.removeCachedPath(any())).thenAnswer((inv) async {
      cache.remove(inv.positionalArguments[0] as String);
    });
    when(() => local.isSurahDownloaded(any())).thenAnswer(
      (inv) => records[inv.positionalArguments[0] as String] ?? false,
    );
    when(() => local.markSurahDownloaded(any())).thenAnswer((inv) async {
      records[inv.positionalArguments[0] as String] = true;
    });
    when(() => local.clearSurahDownloaded(any())).thenAnswer((inv) async {
      records.remove(inv.positionalArguments[0] as String);
    });
    when(
      () => remote.downloadAudio(any(), any()),
    ).thenAnswer((inv) => writeFile(inv.positionalArguments[1] as String));
    repo = QuranPlaybackRepoImpl(
      player: _MockPlayer(),
      remote: remote,
      local: local,
      dir: dir,
    );
    savePath = '${dir.path}/${reciter.folderName}/2/5.mp3';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('failed download is not reused and leaves no partial file', () async {
    var call = 0;
    when(() => remote.downloadAudio(any(), any())).thenAnswer((_) async {
      if (++call == 1) {
        File(savePath).writeAsBytesSync([1, 2, 3]);
        throw DioException(requestOptions: RequestOptions());
      }
      return savePath;
    });

    final first = await repo.prepareAyahAudio(ayah: ayah, reciter: reciter);
    expect(first.isLeft(), isTrue);
    expect(File(savePath).existsSync(), isFalse);

    final second = await repo.prepareAyahAudio(ayah: ayah, reciter: reciter);
    expect(second.isRight(), isTrue);
    verify(() => remote.downloadAudio(any(), any())).called(2);
  });

  test('concurrent prepares share one download', () async {
    final completer = Completer<String>();
    when(
      () => remote.downloadAudio(any(), any()),
    ).thenAnswer((_) => completer.future);

    final a = repo.prepareAyahAudio(ayah: ayah, reciter: reciter);
    final b = repo.prepareAyahAudio(ayah: ayah, reciter: reciter);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    completer.complete(savePath);
    final results = await Future.wait([a, b]);

    expect(results.every((r) => r.isRight()), isTrue);
    verify(() => remote.downloadAudio(any(), any())).called(1);
  });

  group('holdPlayback', () {
    late _MockPlayer player;

    setUp(() {
      player = _MockPlayer();
      repo = QuranPlaybackRepoImpl(
        player: player,
        remote: remote,
        local: local,
        dir: dir,
      );
      when(() => player.play()).thenAnswer((_) async {});
    });

    test('plays once the source is set when not held', () async {
      when(() => player.setFilePath(any())).thenAnswer((_) async => null);

      await repo.playPreparedAudio('/a.mp3');

      verify(() => player.play()).called(1);
    });

    test('a hold raised while the source loads skips play', () async {
      final loading = Completer<Duration?>();
      when(() => player.setFilePath(any())).thenAnswer((_) => loading.future);
      when(() => player.pause()).thenAnswer((_) async {});

      final played = repo.playPreparedAudio('/a.mp3');
      repo.holdPlayback(true);
      await repo.pause();
      loading.complete(null);
      final result = await played;

      expect(result.isRight(), isTrue);
      verifyNever(() => player.play());
    });

    test('a hold raised while a sequence loads skips play', () async {
      final loading = Completer<Duration?>();
      when(
        () => player.setAudioSources(any()),
      ).thenAnswer((_) => loading.future);

      final played = repo.playPreparedAudioSequence(['/a.mp3', '/b.mp3']);
      repo.holdPlayback(true);
      loading.complete(null);
      await played;

      verifyNever(() => player.play());
    });

    test('releasing the hold lets the next load play', () async {
      when(() => player.setFilePath(any())).thenAnswer((_) async => null);

      repo.holdPlayback(true);
      repo.holdPlayback(false);
      await repo.playPreparedAudio('/a.mp3');

      verify(() => player.play()).called(1);
    });
  });

  group('surah download', () {
    String urlOf(int surah, int ayah) => reciter.getAyahUrl(surah, ayah);

    test(
      'downloadSurah 112 fetches the basmala and four ayat, then marks it',
      () async {
        var reachedTotalBeforeMark = false;
        final events = <Either<Failure, double>>[];
        when(() => local.markSurahDownloaded(any())).thenAnswer((inv) async {
          reachedTotalBeforeMark = events.contains(
            const Right<Failure, double>(1.0),
          );
          records[inv.positionalArguments[0] as String] = true;
        });
        await repo
            .downloadSurah(surah: 112, reciter: reciter)
            .forEach(events.add);

        final values = events.map((e) => e.getOrElse(() => -1)).toList();
        expect(values.last, 1.0);
        expect(values, orderedEquals([...values]..sort()));
        expect(events.every((e) => e.isRight()), isTrue);
        expect(reachedTotalBeforeMark, isFalse);
        final urls = verify(
          () => remote.downloadAudio(captureAny(), any()),
        ).captured;
        expect(urls, hasLength(5));
        expect(urls, contains(urlOf(1, 1)));
        verify(() => local.markSurahDownloaded('alafasy:112')).called(1);
      },
    );

    test('surahs 1 and 9 fetch no extra basmala', () async {
      await download(9);
      verifyNever(() => remote.downloadAudio(urlOf(1, 1), any()));
      verify(() => remote.downloadAudio(any(), any())).called(129);

      clearInteractions(remote);
      await download(1);
      verify(() => remote.downloadAudio(any(), any())).called(7);
    });

    test('cached ayat are skipped and count as done', () async {
      seed(const AyahIdentifier(surah: 112, ayah: 1));
      seed(const AyahIdentifier(surah: 1, ayah: 1));
      final gate = Completer<void>();
      when(() => remote.downloadAudio(any(), any())).thenAnswer((inv) async {
        await gate.future;
        return writeFile(inv.positionalArguments[1] as String);
      });

      final events = <Either<Failure, double>>[];
      final sub = repo
          .downloadSurah(surah: 112, reciter: reciter)
          .listen(events.add);
      await pumpEventQueue();
      expect(events, [const Right(2 / 5)]);

      gate.complete();
      await sub.asFuture<void>();
      verify(() => remote.downloadAudio(any(), any())).called(3);
      expect(events.last, const Right(1.0));
    });

    test('everything cached marks at once', () async {
      for (final a in [1, 2, 3, 4]) {
        seed(AyahIdentifier(surah: 112, ayah: a));
      }
      seed(const AyahIdentifier(surah: 1, ayah: 1));

      final events = await download(112);

      expect(events, [const Right(1.0)]);
      verifyNever(() => remote.downloadAudio(any(), any()));
      verify(() => local.markSurahDownloaded('alafasy:112')).called(1);
    });

    test(
      'a failed ayah ends with Left, no record, finished files kept',
      () async {
        when(() => remote.downloadAudio(any(), any())).thenAnswer((inv) {
          if (inv.positionalArguments[0] == urlOf(112, 3)) {
            throw DioException(requestOptions: RequestOptions());
          }
          return writeFile(inv.positionalArguments[1] as String);
        });

        final events = await download(112);

        expect(events.last.isLeft(), isTrue);
        verifyNever(() => local.markSurahDownloaded(any()));
        expect(
          File(pathOf(const AyahIdentifier(surah: 112, ayah: 1))).existsSync(),
          isTrue,
        );
      },
    );

    test('cancel drops queued ayat and keeps finished files; a new download '
        'resumes', () async {
      final completers = <String, Completer<String>>{};
      when(() => remote.downloadAudio(any(), any())).thenAnswer((inv) {
        final url = inv.positionalArguments[0] as String;
        return (completers[url] = Completer<String>()).future;
      });
      Future<void> finish(String url, AyahIdentifier a) async {
        completers[url]!.complete(await writeFile(pathOf(a)));
        await pumpEventQueue();
      }

      final events = <Either<Failure, double>>[];
      final sub = repo
          .downloadSurah(surah: 112, reciter: reciter)
          .listen(events.add);
      await pumpEventQueue();
      await finish(urlOf(1, 1), const AyahIdentifier(surah: 1, ayah: 1));
      await sub.cancel();
      final countAtCancel = events.length;
      await finish(urlOf(112, 1), const AyahIdentifier(surah: 112, ayah: 1));
      await finish(urlOf(112, 2), const AyahIdentifier(surah: 112, ayah: 2));
      verify(() => remote.downloadAudio(any(), any())).called(3);
      expect(events, hasLength(countAtCancel));
      verifyNever(() => local.markSurahDownloaded(any()));

      clearInteractions(remote);
      when(
        () => remote.downloadAudio(any(), any()),
      ).thenAnswer((inv) => writeFile(inv.positionalArguments[1] as String));
      await download(112);

      final urls = verify(
        () => remote.downloadAudio(captureAny(), any()),
      ).captured;
      expect(urls, unorderedEquals([urlOf(112, 3), urlOf(112, 4)]));
    });

    test('cancelling with the final ayah in flight leaves no record', () async {
      for (final a in [1, 2, 3]) {
        seed(AyahIdentifier(surah: 112, ayah: a));
      }
      seed(const AyahIdentifier(surah: 1, ayah: 1));
      final gate = Completer<void>();
      when(() => remote.downloadAudio(any(), any())).thenAnswer((inv) async {
        await gate.future;
        return writeFile(inv.positionalArguments[1] as String);
      });

      final events = <Either<Failure, double>>[];
      var closed = false;
      final sub = repo
          .downloadSurah(surah: 112, reciter: reciter)
          .listen(events.add, onDone: () => closed = true);
      await pumpEventQueue();
      final countAtCancel = events.length;
      await sub.cancel();
      gate.complete();
      await pumpEventQueue();

      expect(events, hasLength(countAtCancel));
      expect(closed, isFalse);
      verifyNever(() => local.markSurahDownloaded(any()));
      expect(repo.isSurahDownloaded(surah: 112, reciter: reciter), isFalse);
    });

    test('a failing record write ends the stream with Left', () async {
      when(() => local.markSurahDownloaded(any())).thenThrow(Exception('hive'));

      final events = await download(112);

      expect(events.last.isLeft(), isTrue);
    });

    test(
      'a failing record write with everything cached ends with Left',
      () async {
        for (final a in [1, 2, 3, 4]) {
          seed(AyahIdentifier(surah: 112, ayah: a));
        }
        seed(const AyahIdentifier(surah: 1, ayah: 1));
        when(
          () => local.markSurahDownloaded(any()),
        ).thenThrow(Exception('hive'));

        final events = await download(112);

        expect(events, hasLength(1));
        expect(events.single.isLeft(), isTrue);
      },
    );

    test('a preload goes ahead of a queued surah download', () async {
      final completers = <String, Completer<String>>{};
      final order = <String>[];
      when(() => remote.downloadAudio(any(), any())).thenAnswer((inv) {
        final url = inv.positionalArguments[0] as String;
        order.add(url);
        return (completers[url] = Completer<String>()).future;
      });

      final sub = repo
          .downloadSurah(surah: 112, reciter: reciter)
          .listen((_) {});
      await pumpEventQueue();
      expect(order, hasLength(2));

      await repo.preloadAyahs(
        ayahs: const [AyahIdentifier(surah: 2, ayah: 255)],
        reciter: reciter,
      );
      completers[order.first]!.complete(
        await writeFile(pathOf(const AyahIdentifier(surah: 1, ayah: 1))),
      );
      await pumpEventQueue();

      expect(order[2], urlOf(2, 255));
      await sub.cancel();
    });

    test('deleteSurahDownload removes files, cache entries and the record '
        'but keeps 1:1', () async {
      await download(112);

      final result = await repo.deleteSurahDownload(
        surah: 112,
        reciter: reciter,
      );

      expect(result.isRight(), isTrue);
      for (final a in [1, 2, 3, 4]) {
        final id = AyahIdentifier(surah: 112, ayah: a);
        expect(File(pathOf(id)).existsSync(), isFalse);
        expect(cache.containsKey(urlOf(112, a)), isFalse);
      }
      expect(
        File(pathOf(const AyahIdentifier(surah: 1, ayah: 1))).existsSync(),
        isTrue,
      );
      expect(cache.containsKey(urlOf(1, 1)), isTrue);
      expect(records.containsKey('alafasy:112'), isFalse);
    });

    test(
      'deleting surah 1 keeps 1:1 so other surahs keep their basmala',
      () async {
        await download(1);
        await download(112);

        await repo.deleteSurahDownload(surah: 1, reciter: reciter);

        for (final a in [2, 3, 4, 5, 6, 7]) {
          expect(
            File(pathOf(AyahIdentifier(surah: 1, ayah: a))).existsSync(),
            isFalse,
          );
        }
        expect(
          File(pathOf(const AyahIdentifier(surah: 1, ayah: 1))).existsSync(),
          isTrue,
        );
        expect(cache.containsKey(urlOf(1, 1)), isTrue);
        expect(repo.isSurahDownloaded(surah: 112, reciter: reciter), isTrue);
        expect(repo.isSurahDownloaded(surah: 1, reciter: reciter), isFalse);

        clearInteractions(remote);
        await download(1);
        verify(() => remote.downloadAudio(any(), any())).called(6);
      },
    );

    test(
      'delete uses the cached path when it differs from the computed one',
      () async {
        await download(112);
        final other = File('${dir.path}/other.mp3')..writeAsBytesSync([0]);
        cache[urlOf(112, 2)] = other.path;

        await repo.deleteSurahDownload(surah: 112, reciter: reciter);

        expect(other.existsSync(), isFalse);
      },
    );

    test('isSurahDownloaded reads the record', () {
      records['husary:2'] = true;

      expect(repo.isSurahDownloaded(surah: 2, reciter: Reciter.husary), isTrue);
      expect(repo.isSurahDownloaded(surah: 2, reciter: reciter), isFalse);
    });

    test('a cache entry from an old app container resolves to the file '
        'under the current directory and is refreshed', () async {
      const a = AyahIdentifier(surah: 3, ayah: 1);
      seed(a);
      cache[urlOf(3, 1)] = '/old/container/Documents/alafasy/3/1.mp3';

      expect(repo.isAyahCached(ayah: a, reciter: reciter), isTrue);
      await pumpEventQueue();
      expect(cache[urlOf(3, 1)], pathOf(a));

      cache[urlOf(3, 1)] = '/old/container/Documents/alafasy/3/1.mp3';
      final result = await repo.prepareAyahAudio(ayah: a, reciter: reciter);
      expect(result, Right<Failure, String>(pathOf(a)));
      verifyNever(() => remote.downloadAudio(any(), any()));
    });

    test('a stale entry with no file anywhere is not cached', () {
      const a = AyahIdentifier(surah: 3, ayah: 1);
      cache[urlOf(3, 1)] = '/old/container/Documents/alafasy/3/1.mp3';
      expect(repo.isAyahCached(ayah: a, reciter: reciter), isFalse);
    });

    test('isAyahCached needs both the cache entry and the file', () {
      const a = AyahIdentifier(surah: 3, ayah: 1);
      cache[urlOf(3, 1)] = pathOf(a);
      expect(repo.isAyahCached(ayah: a, reciter: reciter), isFalse);

      seed(a);
      expect(repo.isAyahCached(ayah: a, reciter: reciter), isTrue);
    });
  });
}
