import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/preview_alert_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/stop_alert_preview.dart';
import 'package:quran_app/features/notifications/presentation/cubit/sound_preview_cubit.dart';

class _MockPreview extends Mock implements PreviewAlertSound {}

class _MockStop extends Mock implements StopAlertPreview {}

void main() {
  late _MockPreview preview;
  late _MockStop stop;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(
      const PreviewAlertSoundParams(
        sound: PreviewSound.tone,
        prayer: PrayerName.fajr,
      ),
    );
  });

  setUp(() {
    preview = _MockPreview();
    stop = _MockStop();
    when(() => preview(any())).thenAnswer((_) async => const Right(unit));
    when(() => stop(any())).thenAnswer((_) async => const Right(unit));
  });

  blocTest<SoundPreviewCubit, PreviewSound?>(
    'play then play same stops',
    build: () => SoundPreviewCubit(preview, stop),
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
    build: () => SoundPreviewCubit(preview, stop),
    act: (c) {
      c.play(PreviewSound.adhan, PrayerName.dhuhr);
      c.play(PreviewSound.tone, PrayerName.dhuhr);
    },
    expect: () => [PreviewSound.adhan, PreviewSound.tone],
  );

  test('SoundPreviewCubit.close stops the preview', () async {
    final cubit = SoundPreviewCubit(preview, stop);
    await cubit.close();
    verify(() => stop(any())).called(1);
  });
}
