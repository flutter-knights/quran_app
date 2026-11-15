import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class PreviewAlertSoundParams {
  final PreviewSound sound;
  final PrayerName prayer;

  const PreviewAlertSoundParams({required this.sound, required this.prayer});
}

class PreviewAlertSound
    extends UseCase<Either<Failure, Unit>, PreviewAlertSoundParams> {
  final NotificationsRepository repository;
  PreviewAlertSound({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(PreviewAlertSoundParams params) =>
      repository.previewSound(sound: params.sound, prayer: params.prayer);
}
