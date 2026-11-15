import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/preview_alert_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/stop_alert_preview.dart';
import 'package:quran_app/features/notifications/domain/usecases/watch_preview_ended.dart';
import 'package:quran_app/features/notifications/presentation/cubit/sound_preview_cubit.dart';

class _MockPreview extends Mock implements PreviewAlertSound {}

class _MockStop extends Mock implements StopAlertPreview {}

class _MockWatchEnded extends Mock implements WatchPreviewEnded {}

void main() {
  late _MockPreview preview;
  late _MockStop stop;
  late _MockWatchEnded watchEnded;
  late StreamController<PreviewSound> ended;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(
      const PreviewAlertSoundParams(
        sound: PreviewSound.tone,
        prayer: PrayerName.fajr,
      ),
    );
  });

  tearDown(() => ended.close());

  setUp(() {
    preview = _MockPreview();
    stop = _MockStop();
    watchEnded = _MockWatchEnded();
    ended = StreamController<PreviewSound>.broadcast();
    when(() => watchEnded(any())).thenAnswer((_) => ended.stream);
    when(() => preview(any())).thenAnswer((_) async => const Right(unit));
    when(() => stop(any())).thenAnswer((_) async => const Right(unit));
  });

  blocTest<SoundPreviewCubit, PreviewSound?>(
    'play then play same stops',
    build: () => SoundPreviewCubit(preview, stop, watchEnded),
    act: (c) {
      c.play(PreviewSound.adhan, PrayerName.fajr);
      c.play(PreviewSound.adhan, PrayerName.fajr);
    },
    expect: () => [PreviewSound.adhan, null],
    verify: (_) {
      final p =
          verify(() => preview(captureAny())).captured.single
              as PreviewAlertSoundParams;
      expect((p.sound, p.prayer), (PreviewSound.adhan, PrayerName.fajr));
      verify(() => stop(any())).called(greaterThanOrEqualTo(1));
    },
  );

  blocTest<SoundPreviewCubit, PreviewSound?>(
    'playing another sound switches to it',
    build: () => SoundPreviewCubit(preview, stop, watchEnded),
    act: (c) {
      c.play(PreviewSound.adhan, PrayerName.dhuhr);
      c.play(PreviewSound.tone, PrayerName.dhuhr);
    },
    expect: () => [PreviewSound.adhan, PreviewSound.tone],
  );

  test('SoundPreviewCubit.close stops the preview', () async {
    final cubit = SoundPreviewCubit(preview, stop, watchEnded);
    await cubit.close();
    verify(() => stop(any())).called(1);
  });

  blocTest<SoundPreviewCubit, PreviewSound?>(
    'a clip that ends by itself clears the playing sound',
    build: () => SoundPreviewCubit(preview, stop, watchEnded),
    act: (c) async {
      await c.play(PreviewSound.adhan, PrayerName.fajr);
      ended.add(PreviewSound.adhan);
    },
    expect: () => [PreviewSound.adhan, null],
  );

  blocTest<SoundPreviewCubit, PreviewSound?>(
    'an end event for another sound is ignored',
    build: () => SoundPreviewCubit(preview, stop, watchEnded),
    act: (c) async {
      await c.play(PreviewSound.tone, PrayerName.fajr);
      ended.add(PreviewSound.adhan);
    },
    expect: () => [PreviewSound.tone],
  );

  test('close cancels the end subscription', () async {
    final cubit = SoundPreviewCubit(preview, stop, watchEnded);
    expect(ended.hasListener, isTrue);
    await cubit.close();
    expect(ended.hasListener, isFalse);
  });
}
