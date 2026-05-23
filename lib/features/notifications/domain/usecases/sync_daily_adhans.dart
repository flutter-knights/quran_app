import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class SyncDailyAdhansParams {
  final PrayerTimes prayerTimes;
  final AdhanAudioSettings? audio;
  final String localeCode;
  const SyncDailyAdhansParams({
    required this.prayerTimes,
    required this.localeCode,
    this.audio,
  });
}

class SyncDailyAdhans
    extends UseCase<Either<Failure, Unit>, SyncDailyAdhansParams> {
  final NotificationsRepository repository;
  SyncDailyAdhans({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(SyncDailyAdhansParams params) =>
      repository.scheduleDailyAdhans(
        prayerTimes: params.prayerTimes,
        audio: params.audio ?? AdhanAudioSettings.defaults(),
        localeCode: params.localeCode,
      );
}
