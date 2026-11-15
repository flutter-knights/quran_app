import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/preview_alert_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/stop_alert_preview.dart';

class SoundPreviewCubit extends Cubit<PreviewSound?> {
  SoundPreviewCubit(this._preview, this._stop) : super(null);

  final PreviewAlertSound _preview;
  final StopAlertPreview _stop;

  Future<void> play(PreviewSound sound, PrayerName prayer) async {
    if (state == sound) return stop();
    emit(sound);
    final result = await _preview(
      PreviewAlertSoundParams(sound: sound, prayer: prayer),
    );
    if (isClosed || result.isRight() || state != sound) return;
    emit(null);
  }

  Future<void> stop() async {
    if (state != null) emit(null);
    await _stop(NoParams());
  }

  @override
  Future<void> close() async {
    await _stop(NoParams());
    return super.close();
  }
}
