import 'dart:async';

import 'package:audio_service/audio_service.dart' hide PlaybackState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/quran_audio_handler.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

class _MockPlayer extends Mock implements AudioPlayer {}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());
  final calls = <String>[];

  void push(PlaybackState state) => emit(state);

  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> skipNext() async => calls.add('next');
  @override
  Future<void> skipPrevious() async => calls.add('prev');
  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inSeconds}');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _MockPlayer player;
  late StreamController<PlaybackEvent> events;
  late StreamController<Duration?> durations;
  late QuranAudioHandler handler;
  late _FakePlayback cubit;
  var lang = 'ar';

  const ayah25 = AyahIdentifier(surah: 2, ayah: 5);

  setUp(() {
    player = _MockPlayer();
    events = StreamController<PlaybackEvent>.broadcast();
    durations = StreamController<Duration?>.broadcast();
    when(() => player.playbackEventStream).thenAnswer((_) => events.stream);
    when(() => player.durationStream).thenAnswer((_) => durations.stream);
    when(() => player.playing).thenReturn(true);
    when(() => player.processingState).thenReturn(ProcessingState.ready);
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.bufferedPosition).thenReturn(Duration.zero);
    when(() => player.speed).thenReturn(1.0);
    lang = 'ar';
    handler = QuranAudioHandler(player: player, langCode: () => lang);
    cubit = _FakePlayback();
  });

  tearDown(() async {
    await events.close();
    await durations.close();
    await cubit.close();
  });

  test('OS commands route to the attached cubit', () async {
    handler.attach(cubit);
    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.seek(const Duration(seconds: 3));
    await handler.stop();
    await handler.onTaskRemoved();
    expect(cubit.calls, [
      'resume',
      'pause',
      'next',
      'prev',
      'seek:3',
      'stop',
      'stop',
    ]);
  });

  test('commands before attach do nothing', () async {
    await handler.play();
    await handler.skipToNext();
    await handler.onTaskRemoved();
    handler.attach(cubit);
    expect(cubit.calls, isEmpty);
  });

  test('a new ayah publishes its MediaItem', () async {
    handler.attach(cubit);
    final published = <MediaItem?>[];
    handler.mediaItem.skip(1).listen(published.add);
    cubit.push(
      const PlaybackState(requestedAyah: ayah25, reciter: Reciter.husary),
    );
    await pumpEventQueue();
    expect(handler.mediaItem.value!.id, 'husary:2:5');
    cubit.push(
      const PlaybackState(
        requestedAyah: ayah25,
        reciter: Reciter.husary,
        isPlaying: true,
      ),
    );
    await pumpEventQueue();
    expect(published, hasLength(1));
  });

  test('stopping clears the MediaItem once', () async {
    handler.attach(cubit);
    cubit.push(const PlaybackState(requestedAyah: ayah25));
    await pumpEventQueue();
    final published = <MediaItem?>[];
    handler.mediaItem.skip(1).listen(published.add);
    cubit.push(const PlaybackState());
    await pumpEventQueue();
    cubit.push(const PlaybackState(error: 'x'));
    await pumpEventQueue();
    expect(handler.mediaItem.value, isNull);
    expect(published, [null]);
    durations.add(const Duration(seconds: 9));
    await pumpEventQueue();
    expect(handler.mediaItem.value, isNull);
  });

  test('a player event broadcasts the four controls', () async {
    events.add(PlaybackEvent());
    await pumpEventQueue();
    final state = handler.playbackState.value;
    expect(state.controls, [
      MediaControl.skipToPrevious,
      MediaControl.pause,
      MediaControl.skipToNext,
      MediaControl.stop,
    ]);
    expect(state.playing, isTrue);
    expect(state.processingState, AudioProcessingState.ready);
    expect(state.androidCompactActionIndices, [0, 1, 2]);
    expect(state.systemActions, {MediaAction.seek});
    expect(state.speed, 1.0);
  });

  test('a paused player broadcasts the play control', () async {
    when(() => player.playing).thenReturn(false);
    events.add(PlaybackEvent());
    await pumpEventQueue();
    final state = handler.playbackState.value;
    expect(state.controls[1], MediaControl.play);
    expect(state.playing, isFalse);
  });

  test(
    'a language switch retitles the MediaItem and keeps its duration',
    () async {
      handler.attach(cubit);
      const playing = PlaybackState(
        requestedAyah: ayah25,
        reciter: Reciter.husary,
      );
      cubit.push(playing);
      await pumpEventQueue();
      durations.add(const Duration(seconds: 9));
      await pumpEventQueue();
      final arabicTitle = handler.mediaItem.value!.title;
      lang = 'en';
      cubit.push(playing.copyWith(isPlaying: true));
      await pumpEventQueue();
      final item = handler.mediaItem.value!;
      expect(item.title, isNot(arabicTitle));
      expect(item.id, 'husary:2:5');
      expect(item.duration, const Duration(seconds: 9));
    },
  );

  test('duration reaches the current MediaItem', () async {
    handler.attach(cubit);
    cubit.push(const PlaybackState(requestedAyah: ayah25));
    await pumpEventQueue();
    durations.add(const Duration(seconds: 9));
    await pumpEventQueue();
    expect(handler.mediaItem.value!.duration, const Duration(seconds: 9));
  });
}
