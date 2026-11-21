import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';

class PlaybackAudioFocus {
  PlaybackAudioFocus({
    required Stream<AudioInterruptionEvent> interruptions,
    required Stream<void> becomingNoisy,
    required PlaybackCubit cubit,
  }) : _cubit = cubit {
    _subscriptions = [
      interruptions.listen((event) {
        if (event.begin) _pause();
      }),
      becomingNoisy.listen((_) => _pause()),
      cubit.stream.listen((state) {
        if (state.skipOrigin == null) {
          _pending = false;
        } else if (_pending && state.isPlaying) {
          _pending = false;
          cubit.pause();
        }
      }),
    ];
  }

  final PlaybackCubit _cubit;
  late final List<StreamSubscription<Object?>> _subscriptions;
  var _pending = false;

  void _pause() {
    final state = _cubit.state;
    if (state.isPlaying) {
      _cubit.pause();
    } else if (state.isLoading) {
      _pending = true;
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}

Future<PlaybackAudioFocus?> connectAudioFocus({
  required Future<AudioSession> Function() session,
  required PlaybackCubit cubit,
}) async {
  try {
    final s = await session();
    await s.configure(const AudioSessionConfiguration.speech());
    return PlaybackAudioFocus(
      interruptions: s.interruptionEventStream,
      becomingNoisy: s.becomingNoisyEventStream,
      cubit: cubit,
    );
  } catch (e) {
    debugPrint('audio focus unavailable: $e');
    return null;
  }
}
