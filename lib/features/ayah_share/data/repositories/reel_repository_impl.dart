import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dartz/dartz.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/reel_request.dart';
import '../../domain/repositories/reel_repository.dart';

typedef ReelFrame = ({int clip, Duration duration});
typedef ReelTrack = ({String path, Duration start});
typedef ReelPlan = ({List<ReelFrame> frames, List<ReelTrack> tracks});

const reelAndroidStep = 0.2;
const reelIosStep = 1.0;
const reelFrameRate = 5.0;

const _microsPerSecond = 1000000;
const _minRemainderMicros = 33333;

ReelPlan reelPlan(
  ReelRequest request, {
  required bool ios,
  double iosStep = reelIosStep,
}) {
  final clips = request.clips;
  final step = ios ? iosStep : reelAndroidStep;
  final offsets = [Duration.zero];
  for (final clip in clips) {
    offsets.add(offsets.last + clip.duration);
  }
  int snap(Duration offset) =>
      ((offset.inMicroseconds / _microsPerSecond / step).round() *
              step *
              _microsPerSecond)
          .round();

  final bounds = [
    for (var i = 0; i < clips.length; i++) snap(offsets[i]),
    ios && iosStep == 1
        ? (offsets.last.inMicroseconds / _microsPerSecond).ceil() *
              _microsPerSecond
        : snap(offsets.last),
  ];

  final frames = <ReelFrame>[];
  for (var i = 0; i < clips.length; i++) {
    final span = bounds[i + 1] - bounds[i];
    if (!ios) {
      if (span > 0) {
        frames.add((clip: i, duration: Duration(microseconds: span)));
      }
      continue;
    }
    final whole = span ~/ _microsPerSecond;
    final remainder = span - whole * _microsPerSecond;
    for (var k = 0; k < whole; k++) {
      frames.add((clip: i, duration: const Duration(seconds: 1)));
    }
    if (remainder >= _minRemainderMicros) {
      frames.add((clip: i, duration: Duration(microseconds: remainder)));
    }
  }

  final tracks = <ReelTrack>[];
  for (var i = 0; i < clips.length; i++) {
    var start = offsets[i];
    for (final audio in clips[i].audio) {
      tracks.add((path: audio.path, start: start));
      start += audio.duration;
    }
  }
  return (frames: frames, tracks: tracks);
}

class ReelRepositoryImpl implements ReelRepository {
  ReelRepositoryImpl({
    ProVideoEditor? editor,
    Future<Directory> Function() directory = getApplicationSupportDirectory,
    bool? ios,
  }) : _override = editor,
       _directory = directory,
       _ios = ios ?? Platform.isIOS;

  final ProVideoEditor? _override;
  final Future<Directory> Function() _directory;
  final bool _ios;
  final _progress = StreamController<double>.broadcast();
  final _running = <String>{};
  var _count = 0;
  var _cancelledThrough = 0;

  ProVideoEditor get _editor => _override ?? ProVideoEditor.instance;

  @override
  Stream<double> get progress => _progress.stream;

  bool _cancelled(int n) => n <= _cancelledThrough;

  @override
  Future<Either<Failure, Duration>> audioDuration(String path) async {
    try {
      final metadata = await _editor.getMetadata(EditorVideo.file(File(path)));
      return Right(metadata.audioDuration ?? metadata.duration);
    } catch (e) {
      return Left(UnknownFailure('$e'));
    }
  }

  @override
  Future<Either<Failure, String>> compose(ReelRequest request) async {
    final n = ++_count;
    File? output;
    Directory? work;
    try {
      final root = Directory('${(await _directory()).path}/ayah_share');
      final reels = Directory('${root.path}/reels');
      work = Directory('${root.path}/work/$n');
      output = File('${reels.path}/${request.fileName}');
      await _delete(reels);
      await work.create(recursive: true);
      await reels.create();

      final plan = reelPlan(request, ios: _ios);
      for (var i = 0; i < request.clips.length; i++) {
        await File(
          '${work.path}/frame_$i.png',
        ).writeAsBytes(request.clips[i].frame);
      }
      if (_cancelled(n)) throw const RenderCanceledException();

      final silent = '${work.path}/silent.mp4';
      final framesData = StopMotionRenderData(
        id: 'reel-frames-$n',
        frames: [
          for (final frame in plan.frames)
            StopMotionFrame(
              image: EditorLayerImage.file(
                File('${work.path}/frame_${frame.clip}.png'),
              ),
              duration: frame.duration,
            ),
        ],
        frameRate: reelFrameRate,
        resolution: const Size(1080, 1920),
        fit: StopMotionFit.cover,
      );
      await _pass(
        framesData.id,
        0,
        () => _editor.renderStopMotionToFile(silent, framesData),
      );
      if (_cancelled(n)) throw const RenderCanceledException();

      final audioData = VideoRenderData(
        id: 'reel-audio-$n',
        videoSegments: [VideoSegment(video: EditorVideo.file(File(silent)))],
        audioTracks: [
          for (final track in plan.tracks)
            VideoAudioTrack(path: track.path, startTime: track.start),
        ],
        shouldOptimizeForNetworkUse: true,
      );
      await _pass(
        audioData.id,
        0.5,
        () => _editor.renderVideoToFile(output!.path, audioData),
      );
      return Right(output.path);
    } on RenderCanceledException {
      await _delete(output);
      return const Left(ReelCancelledFailure());
    } catch (e) {
      await _delete(output);
      return Left(UnknownFailure('$e'));
    } finally {
      await _delete(work);
    }
  }

  Future<void> _pass(
    String id,
    double from,
    Future<void> Function() render,
  ) async {
    final sub = _editor
        .progressStreamById(id)
        .listen((event) => _progress.add(from + event.progress / 2));
    _running.add(id);
    try {
      await render();
    } finally {
      _running.remove(id);
      await sub.cancel();
    }
  }

  Future<void> _delete(FileSystemEntity? entity) async {
    if (entity != null && await entity.exists()) {
      await entity.delete(recursive: true);
    }
  }

  @override
  Future<void> cancel() async {
    _cancelledThrough = _count;
    for (final id in [..._running]) {
      try {
        await _editor.cancel(id);
      } catch (_) {}
    }
  }
}
