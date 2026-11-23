import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/domain/entities/reel_request.dart';
import 'package:quran_app/features/ayah_share/domain/repositories/reel_repository.dart';
import 'package:quran_app/features/ayah_share/domain/usecases/prepare_ayah_audio.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';

class _FakePlayback implements QuranPlaybackRepo {
  final requests = <AyahIdentifier>[];
  final failing = <AyahIdentifier>{};

  @override
  Future<Either<Failure, String>> prepareAyahAudio({
    required AyahIdentifier ayah,
    required Reciter reciter,
  }) async {
    requests.add(ayah);
    if (failing.contains(ayah)) return const Left(NetworkFailure('offline'));
    return Right('/a/${ayah.surah}_${ayah.ayah}.mp3');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReels implements ReelRepository {
  final durations = <String, Duration>{};
  var failDuration = false;

  @override
  Future<Either<Failure, Duration>> audioDuration(String path) async =>
      failDuration
      ? const Left(UnknownFailure('probe'))
      : Right(durations[path] ?? const Duration(seconds: 5));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePlayback playback;
  late _FakeReels reels;
  late PrepareAyahAudio prepare;

  setUp(() {
    playback = _FakePlayback();
    reels = _FakeReels();
    prepare = PrepareAyahAudio(playback: playback, reels: reels);
  });

  test('ayah 1 of most surahs gets the basmala first', () async {
    reels.durations['/a/1_1.mp3'] = const Duration(milliseconds: 6031);
    reels.durations['/a/2_1.mp3'] = const Duration(milliseconds: 3200);

    final result = await prepare(
      const AyahIdentifier(surah: 2, ayah: 1),
      Reciter.alafasy,
    );

    expect(result.toOption().toNullable(), const [
      ReelAudio(path: '/a/1_1.mp3', duration: Duration(milliseconds: 6031)),
      ReelAudio(path: '/a/2_1.mp3', duration: Duration(milliseconds: 3200)),
    ]);
    expect(playback.requests, const [
      AyahIdentifier(surah: 1, ayah: 1),
      AyahIdentifier(surah: 2, ayah: 1),
    ]);
  });

  test('surahs 1 and 9 start without a basmala', () async {
    for (final surah in [1, 9]) {
      final result = await prepare(
        AyahIdentifier(surah: surah, ayah: 1),
        Reciter.alafasy,
      );

      expect(result.toOption().toNullable(), hasLength(1));
    }
    expect(playback.requests, const [
      AyahIdentifier(surah: 1, ayah: 1),
      AyahIdentifier(surah: 9, ayah: 1),
    ]);
  });

  test('a later ayah is its own audio', () async {
    final result = await prepare(
      const AyahIdentifier(surah: 2, ayah: 255),
      Reciter.alafasy,
    );

    expect(result.toOption().toNullable(), hasLength(1));
  });

  test('a download failure is returned', () async {
    playback.failing.add(const AyahIdentifier(surah: 2, ayah: 1));

    final result = await prepare(
      const AyahIdentifier(surah: 2, ayah: 1),
      Reciter.alafasy,
    );

    expect(
      result,
      const Left<Failure, List<ReelAudio>>(NetworkFailure('offline')),
    );
  });

  test('a duration failure is returned', () async {
    reels.failDuration = true;

    final result = await prepare(
      const AyahIdentifier(surah: 2, ayah: 255),
      Reciter.alafasy,
    );

    expect(result.isLeft(), isTrue);
  });
}
