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
        if (event.begin && event.type != AudioInterruptionType.duck) _pause();
      }),
      becomingNoisy.listen((_) => _pause()),
    ];
  }

  final PlaybackCubit _cubit;
  late final List<StreamSubscription<Object?>> _subscriptions;

  void _pause() {
    final state = _cubit.state;
    if (state.isPlaying || state.isLoading) {
      _cubit.pause();
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
    await s.configure(
      const AudioSessionConfiguration.speech().copyWith(
        androidWillPauseWhenDucked: false,
      ),
    );
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
