import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../cubit/playback/playback_cubit.dart';
import 'now_playing_item.dart';
import 'playback_state_mapper.dart';

class QuranAudioHandler extends BaseAudioHandler {
  QuranAudioHandler({
    required AudioPlayer player,
    required String Function() langCode,
  }) : _player = player,
       _langCode = langCode {
    _player.playbackEventStream.listen(_broadcast);
    _player.durationStream.listen(_onDuration);
  }

  final AudioPlayer _player;
  final String Function() _langCode;
  PlaybackCubit? _cubit;
  StreamSubscription? _cubitSub;

  void attach(PlaybackCubit cubit) {
    _cubitSub?.cancel();
    _cubit = cubit;
    _publish(cubit);
    _cubitSub = cubit.stream.listen((_) => _publish(cubit));
  }

  void _publish(PlaybackCubit cubit) {
    final item = nowPlayingItem(cubit.state, langCode: _langCode());
    final current = mediaItem.value;
    if (item == null) {
      if (current != null) mediaItem.add(null);
    } else if (item.id != current?.id) {
      mediaItem.add(item);
    } else if (item.title != current?.title) {
      mediaItem.add(item.copyWith(duration: current?.duration));
    }
  }

  void _onDuration(Duration? duration) {
    final item = mediaItem.value;
    if (item == null) return;
    mediaItem.add(item.copyWith(duration: duration));
  }

  void _broadcast(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() async => _cubit?.resume();

  @override
  Future<void> pause() async => _cubit?.pause();

  @override
  Future<void> stop() async => _cubit?.stop();

  @override
  Future<void> skipToNext() async => _cubit?.skipNext();

  @override
  Future<void> skipToPrevious() async => _cubit?.skipPrevious();

  @override
  Future<void> seek(Duration position) async => _cubit?.seek(position);

  @override
  Future<void> onTaskRemoved() async => _cubit?.stop();
}
