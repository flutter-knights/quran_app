import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';

class ReelAudio extends Equatable {
  const ReelAudio({required this.path, required this.duration});

  final String path;
  final Duration duration;

  @override
  List<Object> get props => [path, duration];
}

class ReelClip {
  const ReelClip({required this.frame, required this.audio});

  final Uint8List frame;
  final List<ReelAudio> audio;

  Duration get duration =>
      audio.fold(Duration.zero, (sum, track) => sum + track.duration);
}

class ReelRequest {
  const ReelRequest({required this.first, required this.clips});

  final AyahIdentifier first;
  final List<ReelClip> clips;

  String get fileName {
    final base = 'ayah_${first.surah}_${first.ayah}';
    return clips.length == 1
        ? '$base.mp4'
        : '$base-${first.ayah + clips.length - 1}.mp4';
  }
}
