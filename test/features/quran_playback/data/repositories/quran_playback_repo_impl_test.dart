import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
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

  setUp(() {
    dir = Directory.systemTemp.createTempSync('playback_repo_test');
    remote = _MockRemote();
    local = _MockLocal();
    when(() => local.getCachedLocalPath(any())).thenReturn(null);
    when(() => local.cacheAudioMetadata(any(), any())).thenAnswer((_) async {});
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
}
