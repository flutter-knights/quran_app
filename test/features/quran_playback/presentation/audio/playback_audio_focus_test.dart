import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/playback_audio_focus.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());
  var pauses = 0;
  var resumes = 0;

  void push(PlaybackState state) => emit(state);

  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> resume() async => resumes++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSession extends Mock implements AudioSession {}

void main() {
  setUpAll(
    () => registerFallbackValue(const AudioSessionConfiguration.speech()),
  );

  late StreamController<AudioInterruptionEvent> interruptions;
  late StreamController<void> noisy;
  late _FakePlayback cubit;
  late PlaybackAudioFocus focus;

  const ayah25 = AyahIdentifier(surah: 2, ayah: 5);
  const ayah26 = AyahIdentifier(surah: 2, ayah: 6);
  const playing = PlaybackState(currentAyah: ayah25, isPlaying: true);
  const loading = PlaybackState(requestedAyah: ayah25, isLoading: true);

  Future<void> begin(AudioInterruptionType type) async {
    interruptions.add(AudioInterruptionEvent(true, type));
    await pumpEventQueue();
  }

  setUp(() {
    interruptions = StreamController<AudioInterruptionEvent>.broadcast();
    noisy = StreamController<void>.broadcast();
    cubit = _FakePlayback();
    focus = PlaybackAudioFocus(
      interruptions: interruptions.stream,
      becomingNoisy: noisy.stream,
      cubit: cubit,
    );
  });

  tearDown(() async {
    await focus.dispose();
    await interruptions.close();
    await noisy.close();
    await cubit.close();
  });

  test('a call (pause interruption) pauses a playing recitation', () async {
    cubit.push(playing);
    await begin(AudioInterruptionType.pause);
    expect(cubit.pauses, 1);
  });

  test('a duck interruption pauses too: speech is not ducked', () async {
    cubit.push(playing);
    await begin(AudioInterruptionType.duck);
    expect(cubit.pauses, 1);
  });

  test('an unknown interruption pauses', () async {
    cubit.push(playing);
    await begin(AudioInterruptionType.unknown);
    expect(cubit.pauses, 1);
  });

  test('the interruption ending never resumes', () async {
    cubit.push(playing);
    await begin(AudioInterruptionType.pause);
    interruptions.add(
      AudioInterruptionEvent(false, AudioInterruptionType.pause),
    );
    await pumpEventQueue();
    expect(cubit.pauses, 1);
    expect(cubit.resumes, 0);
  });

  test('unplugging headphones pauses', () async {
    cubit.push(playing);
    noisy.add(null);
    await pumpEventQueue();
    expect(cubit.pauses, 1);
  });

  test('nothing happens while already paused', () async {
    cubit.push(const PlaybackState(currentAyah: ayah25, isPaused: true));
    await begin(AudioInterruptionType.pause);
    noisy.add(null);
    await pumpEventQueue();
    expect(cubit.pauses, 0);
  });

  test('dispose stops listening', () async {
    cubit.push(playing);
    await focus.dispose();
    await begin(AudioInterruptionType.pause);
    expect(cubit.pauses, 0);
  });

  test('an interruption during loading pauses straight away', () async {
    cubit.push(loading);
    await begin(AudioInterruptionType.pause);
    expect(cubit.pauses, 1);
  });

  test('unplugging during loading pauses straight away', () async {
    cubit.push(loading);
    noisy.add(null);
    await pumpEventQueue();
    expect(cubit.pauses, 1);
  });

  test('an interruption between ayat pauses', () async {
    cubit.push(const PlaybackState(currentAyah: ayah25, requestedAyah: ayah26));
    await begin(AudioInterruptionType.pause);
    expect(cubit.pauses, 1);
  });

  test('the interruption ending does not resume a loading pause', () async {
    cubit.push(loading);
    await begin(AudioInterruptionType.pause);
    interruptions.add(
      AudioInterruptionEvent(false, AudioInterruptionType.pause),
    );
    await pumpEventQueue();
    expect(cubit.pauses, 1);
    expect(cubit.resumes, 0);
  });

  test('nothing happens when idle', () async {
    await begin(AudioInterruptionType.pause);
    noisy.add(null);
    await pumpEventQueue();
    expect(cubit.pauses, 0);
  });

  test('nothing happens after a failed load', () async {
    cubit.push(const PlaybackState(requestedAyah: ayah25, error: 'offline'));
    await begin(AudioInterruptionType.pause);
    expect(cubit.pauses, 0);
  });

  test('connectAudioFocus configures speech and wires both streams', () async {
    final session = _MockSession();
    final sessionInterruptions =
        StreamController<AudioInterruptionEvent>.broadcast();
    final sessionNoisy = StreamController<void>.broadcast();
    final configs = <AudioSessionConfiguration>[];
    when(() => session.configure(any())).thenAnswer((i) async {
      configs.add(i.positionalArguments.first as AudioSessionConfiguration);
    });
    when(
      () => session.interruptionEventStream,
    ).thenAnswer((_) => sessionInterruptions.stream);
    when(
      () => session.becomingNoisyEventStream,
    ).thenAnswer((_) => sessionNoisy.stream);

    final connected = await connectAudioFocus(
      session: () async => session,
      cubit: cubit,
    );

    expect(connected, isNotNull);
    expect(
      configs.single.toJson(),
      const AudioSessionConfiguration.speech().toJson(),
    );
    cubit.push(playing);
    sessionInterruptions.add(
      AudioInterruptionEvent(true, AudioInterruptionType.pause),
    );
    await pumpEventQueue();
    expect(cubit.pauses, 1);
    sessionNoisy.add(null);
    await pumpEventQueue();
    expect(cubit.pauses, 2);
    await connected!.dispose();
    await sessionInterruptions.close();
    await sessionNoisy.close();
  });

  test('connectAudioFocus survives a session that will not start', () async {
    final result = await connectAudioFocus(
      session: () async => throw Exception('no session'),
      cubit: cubit,
    );
    expect(result, isNull);
  });
}
