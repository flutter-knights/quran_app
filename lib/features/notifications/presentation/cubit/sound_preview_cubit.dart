import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/preview_alert_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/stop_alert_preview.dart';
import 'package:quran_app/features/notifications/domain/usecases/watch_preview_ended.dart';

class SoundPreviewCubit extends Cubit<PreviewSound?> {
  SoundPreviewCubit(this._preview, this._stop, WatchPreviewEnded watchEnded)
    : super(null) {
    _endedSub = watchEnded(NoParams()).listen(_onEnded);
  }

  final PreviewAlertSound _preview;
  final StopAlertPreview _stop;
  late final StreamSubscription<PreviewSound> _endedSub;

  void _onEnded(PreviewSound sound) {
    if (!isClosed && state == sound) emit(null);
  }

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
    await _endedSub.cancel();
    await _stop(NoParams());
    return super.close();
  }
}
