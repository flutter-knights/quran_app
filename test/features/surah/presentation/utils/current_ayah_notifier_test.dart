import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/utils/current_ayah_notifier.dart';

class _FakePlayback extends Mock implements PlaybackCubit {}

void main() {
  late _FakePlayback playback;

  setUp(() {
    playback = _FakePlayback();
  });

  test('initial value is null', () {
    when(() => playback.stream).thenAnswer(
      (_) => const Stream<PlaybackState>.empty(),
    );
    final n = CurrentAyahNotifier(playbackCubit: playback);
    expect(n.value, isNull);
    n.dispose();
  });

  test('forwards distinct currentAyah values from playback stream', () async {
    final controller = StreamController<PlaybackState>();
    addTearDown(controller.close);
    when(() => playback.stream).thenAnswer((_) => controller.stream);

    final n = CurrentAyahNotifier(playbackCubit: playback);
    final seen = <AyahIdentifier?>[];
    n.addListener(() => seen.add(n.value));

    controller.add(const PlaybackState(currentAyah: AyahIdentifier(surah: 1, ayah: 1)));
    await Future<void>.delayed(Duration.zero);
    controller.add(const PlaybackState(currentAyah: AyahIdentifier(surah: 1, ayah: 1))); // dup
    await Future<void>.delayed(Duration.zero);
    controller.add(const PlaybackState(currentAyah: AyahIdentifier(surah: 1, ayah: 2)));
    await Future<void>.delayed(Duration.zero);

    expect(seen.length, 2);
    expect(seen.last, const AyahIdentifier(surah: 1, ayah: 2));
    n.dispose();
  });

  test('translates to (surah, 0) while isPlayingBasmala is true', () async {
    final controller = StreamController<PlaybackState>();
    addTearDown(controller.close);
    when(() => playback.stream).thenAnswer((_) => controller.stream);

    final n = CurrentAyahNotifier(playbackCubit: playback);

    // Basmala intro: bounds JSON indexes the header line as (surah, 0).
    controller.add(const PlaybackState(
      currentAyah: AyahIdentifier(surah: 2, ayah: 1),
      isPlayingBasmala: true,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(n.value, const AyahIdentifier(surah: 2, ayah: 0));

    // Basmala ends → surface the target verse.
    controller.add(const PlaybackState(
      currentAyah: AyahIdentifier(surah: 2, ayah: 1),
    ));
    await Future<void>.delayed(Duration.zero);
    expect(n.value, const AyahIdentifier(surah: 2, ayah: 1));

    n.dispose();
  });
}
