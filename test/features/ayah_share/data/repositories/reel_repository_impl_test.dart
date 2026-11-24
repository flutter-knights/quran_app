import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/data/repositories/reel_repository_impl.dart';
import 'package:quran_app/features/ayah_share/domain/entities/reel_request.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _FakeEditor extends ProVideoEditor {
  final cancelled = <String>[];
  final recorded = <Object>[];
  final _running = <String>{};
  var pass2Calls = 0;
  var framesExisted = false;
  Duration duration = Duration.zero;
  Duration? audioDuration;
  Completer<void>? pass1Gate;
  Completer<void>? pass2Gate;
  final pass1Started = Completer<void>();
  Object? pass1Error;
  Object? pass2Error;
  double? progress;

  @override
  void initializeStream() {}

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async => VideoMetadata(
    duration: duration,
    extension: 'mp3',
    fileSize: 0,
    resolution: Size.zero,
    rotation: 0,
    bitrate: 0,
    audioDuration: audioDuration,
  );

  Future<String> _pass(
    String id,
    String path,
    Completer<void>? gate,
    Object? error,
  ) async {
    _running.add(id);
    try {
      if (progress != null) {
        progressCtrl.add(ProgressModel(id: id, progress: progress!));
        await Future<void>.delayed(Duration.zero);
      }
      await gate?.future;
      if (error != null) throw error;
      await File(path).writeAsBytes([1]);
      return path;
    } finally {
      _running.remove(id);
    }
  }

  @override
  Future<String> renderStopMotionToFile(
    String filePath,
    StopMotionRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) {
    recorded.add(value);
    framesExisted = value.frames.every(
      (f) => File(f.image.file!.path).existsSync(),
    );
    if (!pass1Started.isCompleted) pass1Started.complete();
    return _pass(value.id, filePath, pass1Gate, pass1Error);
  }

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) {
    pass2Calls++;
    recorded.add(value);
    return _pass(value.id, filePath, pass2Gate, pass2Error);
  }

  @override
  Future<void> cancel(String taskId) async {
    if (!_running.contains(taskId)) {
      throw PlatformException(code: 'TASK_NOT_FOUND');
    }
    cancelled.add(taskId);
  }
}

ReelAudio _audio(String path, double seconds) => ReelAudio(
  path: path,
  duration: Duration(microseconds: (seconds * 1e6).round()),
);

ReelRequest _request(double a, double b) => ReelRequest(
  first: const AyahIdentifier(surah: 1, ayah: 1),
  clips: [
    ReelClip(frame: Uint8List(0), audio: [_audio('/a0.mp3', a)]),
    ReelClip(frame: Uint8List(0), audio: [_audio('/a1.mp3', b)]),
  ],
);

ReelRequest _fractional() {
  const seconds = [5.901, 4.444, 7.05, 2.333, 6.789, 3.001, 5.5, 4.123, 6.66];
  return ReelRequest(
    first: const AyahIdentifier(surah: 1, ayah: 1),
    clips: [
      ReelClip(
        frame: Uint8List(0),
        audio: [_audio('/basmala.mp3', 6.031), _audio('/a0.mp3', 3.217)],
      ),
      for (var i = 0; i < seconds.length; i++)
        ReelClip(
          frame: Uint8List(0),
          audio: [_audio('/a${i + 1}.mp3', seconds[i])],
        ),
    ],
  );
}

Duration _sum(Iterable<Duration> durations) =>
    durations.fold(Duration.zero, (a, b) => a + b);

void main() {
  group('reelPlan', () {
    test('android shows one frame per card on 0.2 s steps', () {
      final plan = reelPlan(_request(6.031, 39.478), ios: false);

      expect(plan.frames, [
        (clip: 0, duration: const Duration(seconds: 6)),
        (clip: 1, duration: const Duration(milliseconds: 39600)),
      ]);
    });

    test('ios splits each card into whole seconds and a remainder', () {
      final plan = reelPlan(
        _request(6.031, 39.478),
        ios: true,
        iosStep: 1 / 30,
      );

      final first = plan.frames.where((f) => f.clip == 0).toList();
      final second = plan.frames.where((f) => f.clip == 1).toList();
      expect(first.length, 7);
      expect(
        first.take(6).map((f) => f.duration),
        everyElement(const Duration(seconds: 1)),
      );
      expect(first.last.duration, const Duration(microseconds: 33333));
      expect(second.length, 40);
      expect(
        second.take(39).map((f) => f.duration),
        everyElement(const Duration(seconds: 1)),
      );
      expect(second.last.duration.inMicroseconds, closeTo(499545, 1));
      expect(
        plan.frames.map((f) => f.duration),
        everyElement(lessThanOrEqualTo(const Duration(seconds: 1))),
      );
    });

    test('card switches stay within one step of the audio offsets', () {
      final request = _fractional();
      final total = _sum(request.clips.map((c) => c.duration));
      final offsets = <Duration>[];
      var offset = Duration.zero;
      for (final clip in request.clips) {
        offsets.add(offset);
        offset += clip.duration;
      }

      for (final (ios, iosStep, step) in [
        (false, reelIosStep, reelAndroidStep),
        (true, 1 / 30, 1 / 30),
        (true, 1.0, 1.0),
      ]) {
        final plan = reelPlan(request, ios: ios, iosStep: iosStep);
        final stepUs = (step * 1e6).round() + 1;

        for (var i = 0; i < request.clips.length; i++) {
          final index = plan.frames.indexWhere((f) => f.clip == i);
          final start = _sum(plan.frames.take(index).map((f) => f.duration));
          expect(
            (start - offsets[i]).inMicroseconds.abs(),
            lessThanOrEqualTo(stepUs),
          );
        }

        final video = _sum(plan.frames.map((f) => f.duration));
        expect((video - total).inMicroseconds.abs(), lessThanOrEqualTo(stepUs));
        if (iosStep == 1.0 && ios) {
          expect(video, greaterThanOrEqualTo(total));
          expect(
            plan.frames.map((f) => f.duration),
            everyElement(const Duration(seconds: 1)),
          );
        }
      }
    });

    test('the video never ends before the audio on either platform', () {
      for (final (ios, seconds) in [
        (false, (5.0, 7.29)),
        (false, (6.031, 6.259)),
        (true, (5.0, 7.29)),
        (true, (6.031, 3.0)),
      ]) {
        final request = _request(seconds.$1, seconds.$2);
        final plan = reelPlan(request, ios: ios);

        final video = _sum(plan.frames.map((f) => f.duration));
        final audio = _sum(request.clips.map((c) => c.duration));
        expect(video, greaterThanOrEqualTo(audio));
        expect(
          video - audio,
          lessThan(
            Duration(
              microseconds: ((ios ? reelIosStep : reelAndroidStep) * 1e6)
                  .round(),
            ),
          ),
        );
      }
    });

    test('a card shorter than one step still gets a frame', () {
      final android = reelPlan(_request(0.05, 3), ios: false);
      final ios = reelPlan(_request(0.3, 5), ios: true);

      expect(android.frames.map((f) => f.clip), [0, 1]);
      expect(android.frames.first.duration, const Duration(milliseconds: 200));
      expect(ios.frames.map((f) => f.clip), [0, 1, 1, 1, 1, 1]);
      expect(
        ios.frames.map((f) => f.duration),
        everyElement(const Duration(seconds: 1)),
      );
    });

    test('audio tracks start at the exact offsets, basmala first', () {
      final plan = reelPlan(_fractional(), ios: false);

      expect(plan.tracks.take(4).toList(), [
        (path: '/basmala.mp3', start: Duration.zero),
        (path: '/a0.mp3', start: const Duration(milliseconds: 6031)),
        (path: '/a1.mp3', start: const Duration(milliseconds: 9248)),
        (path: '/a2.mp3', start: const Duration(milliseconds: 15149)),
      ]);
      expect(plan.tracks.length, 11);
    });
  });

  group('ReelRepositoryImpl', () {
    late Directory temp;
    late _FakeEditor editor;
    late ReelRepositoryImpl repo;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('reel_repo');
      editor = _FakeEditor();
      repo = ReelRepositoryImpl(
        editor: editor,
        directory: () async => temp,
        ios: false,
      );
    });

    tearDown(() => temp.deleteSync(recursive: true));

    Directory root(String name) => Directory('${temp.path}/ayah_share/$name');

    ReelRequest request([int ayah = 31]) => ReelRequest(
      first: AyahIdentifier(surah: 6, ayah: ayah),
      clips: [
        ReelClip(frame: Uint8List(2), audio: [_audio('/a0.mp3', 6.031)]),
        ReelClip(frame: Uint8List(2), audio: [_audio('/a1.mp3', 3)]),
      ],
    );

    test(
      'compose renders the silent video, then adds the audio, and cleans up',
      () async {
        final result = await repo.compose(request());

        final path = result.getOrElse(() => '');
        expect(path, endsWith('reels/1/ayah_6_31-32.mp4'));
        expect(File(path).existsSync(), isTrue);
        final pass1 = editor.recorded[0] as StopMotionRenderData;
        expect(editor.framesExisted, isTrue);
        expect(pass1.frames.length, 2);
        expect(pass1.frameRate, 5);
        expect(pass1.resolution, const Size(1080, 1920));
        expect(pass1.fit, StopMotionFit.cover);
        final plan = reelPlan(request(), ios: false);
        expect(
          pass1.frames.map((f) => f.duration),
          plan.frames.map((f) => f.duration),
        );
        expect(pass1.frames.map((f) => f.image.file!.path), [
          for (final frame in plan.frames) endsWith('frame_${frame.clip}.png'),
        ]);
        final pass2 = editor.recorded[1] as VideoRenderData;
        expect(
          pass2.videoSegments!.single.video.file!.path,
          endsWith('silent.mp4'),
        );
        expect(pass2.audioTracks.map((t) => t.path), ['/a0.mp3', '/a1.mp3']);
        expect(pass2.audioTracks.map((t) => t.startTime), [
          Duration.zero,
          const Duration(milliseconds: 6031),
        ]);
        expect(pass2.shouldOptimizeForNetworkUse, isTrue);
        expect(root('work/1').existsSync(), isFalse);
      },
    );

    test(
      'a cancelled render returns ReelCancelledFailure and leaves no files',
      () async {
        editor.pass2Error = const RenderCanceledException();

        final result = await repo.compose(request());

        expect(result.fold((f) => f, (_) => null), isA<ReelCancelledFailure>());
        expect(root('reels').listSync(), isEmpty);
        expect(root('work/1').existsSync(), isFalse);
      },
    );

    test('a render error returns an UnknownFailure', () async {
      editor.pass1Error = StateError('boom');

      final result = await repo.compose(request());

      expect(result.fold((f) => f, (_) => null), isA<UnknownFailure>());
      expect(root('work/1').existsSync(), isFalse);
    });

    test('progress maps pass 1 to 0-0.5 and pass 2 to 0.5-1', () async {
      editor.progress = 0.5;
      final values = <double>[];
      repo.progress.listen(values.add);

      await repo.compose(request());
      await Future<void>.delayed(Duration.zero);

      expect(values, [0.25, 0.75]);
    });

    test('cancel cancels the running pass', () async {
      editor.pass1Gate = Completer();
      final done = repo.compose(request());
      await editor.pass1Started.future;

      await repo.cancel();
      editor.pass1Gate!.complete();
      await done;

      expect(editor.cancelled, ['reel-frames-1']);
    });

    test('a cancel between passes skips pass 2 and leaves no files', () async {
      editor.pass1Gate = Completer();
      final done = repo.compose(request());
      await editor.pass1Started.future;

      await repo.cancel();
      editor.pass1Gate!.complete();
      final result = await done;

      expect(editor.pass2Calls, 0);
      expect(result.fold((f) => f, (_) => null), isA<ReelCancelledFailure>());
      expect(root('reels').listSync(), isEmpty);
      expect(root('work/1').existsSync(), isFalse);
    });

    test('a cancel landing as pass 2 finishes still cancels', () async {
      editor.pass2Gate = Completer();
      final done = repo.compose(request());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(editor.pass2Calls, 1);

      await repo.cancel();
      editor.pass2Gate!.complete();
      final result = await done;

      expect(result.fold((f) => f, (_) => null), isA<ReelCancelledFailure>());
      expect(root('reels').listSync(), isEmpty);
      expect(root('work/1').existsSync(), isFalse);
    });

    test('cancel while idle does not poison the next compose', () async {
      await repo.cancel();
      expect((await repo.compose(request())).isRight(), isTrue);
      await repo.cancel();

      expect(editor.cancelled, isEmpty);
    });

    test('a compose after a cancelled one succeeds', () async {
      editor.pass1Gate = Completer();
      final first = repo.compose(request());
      await editor.pass1Started.future;
      await repo.cancel();
      editor.pass1Gate!.complete();
      expect((await first).isLeft(), isTrue);

      final second = await repo.compose(request());

      expect(second.isRight(), isTrue);
      expect(File(second.getOrElse(() => '')).existsSync(), isTrue);
    });

    test('a late unwind of a cancelled compose keeps the newer reel', () async {
      final gate = Completer<void>();
      editor.pass1Gate = gate;
      final first = repo.compose(request());
      await editor.pass1Started.future;
      await repo.cancel();
      editor.pass1Gate = null;
      final second = await repo.compose(request());

      gate.complete();
      await first;

      expect(second.isRight(), isTrue);
      expect(File(second.getOrElse(() => '')).existsSync(), isTrue);
    });

    test('a compose clears work left by an interrupted export', () async {
      final stale = File('${root('work').path}/3/frame_0.png')
        ..createSync(recursive: true);

      await repo.compose(request());

      expect(stale.existsSync(), isFalse);
      expect(root('work/3').existsSync(), isFalse);
    });

    test('a new compose deletes the previous reel', () async {
      await repo.compose(request());
      await repo.compose(request(32));

      final names = root('reels')
          .listSync(recursive: true)
          .whereType<File>()
          .map((e) => e.uri.pathSegments.last);
      expect(names, ['ayah_6_32-33.mp4']);
    });

    test('discard deletes a finished reel and its slot', () async {
      final path = (await repo.compose(request())).getOrElse(() => '');

      await repo.discard(path);

      expect(File(path).existsSync(), isFalse);
      expect(root('reels/1').existsSync(), isFalse);
    });

    test('a late discard leaves the newer reel alone', () async {
      final first = (await repo.compose(request())).getOrElse(() => '');
      final second = (await repo.compose(request(32))).getOrElse(() => '');

      await repo.discard(first);

      expect(File(second).existsSync(), isTrue);
    });

    test('discard ignores a path outside the reels folder', () async {
      final other = File('${temp.path}/keep/ayah_6_31.mp4')
        ..createSync(recursive: true);

      await repo.discard(other.path);
      await repo.discard('${root('reels').path}/ayah_6_31.mp4');

      expect(other.existsSync(), isTrue);
    });

    test('saveCard writes the card into its own slot', () async {
      final result = await repo.saveCard(Uint8List.fromList([1, 2]), 'a.png');

      final path = result.getOrElse(() => '');
      expect(path, endsWith('reels/1/a.png'));
      expect(File(path).readAsBytesSync(), [1, 2]);
    });

    test('saveCard clears earlier shares and discard removes it', () async {
      final reel = (await repo.compose(request())).getOrElse(() => '');
      final card = (await repo.saveCard(
        Uint8List(1),
        'a.png',
      )).getOrElse(() => '');

      expect(File(reel).existsSync(), isFalse);
      await repo.discard(card);
      expect(root('reels').listSync(), isEmpty);
    });

    test('audioDuration prefers the audio track', () async {
      editor.duration = const Duration(seconds: 7);
      editor.audioDuration = const Duration(seconds: 5);
      expect(
        (await repo.audioDuration('/a.mp3')).getOrElse(() => Duration.zero),
        const Duration(seconds: 5),
      );

      editor.audioDuration = null;
      expect(
        (await repo.audioDuration('/a.mp3')).getOrElse(() => Duration.zero),
        const Duration(seconds: 7),
      );
    });
  });
}
