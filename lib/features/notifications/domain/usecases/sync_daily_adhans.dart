import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class SyncDailyAdhansParams {
  final PrayerTimes prayerTimes;
  final AdhanAudioSettings? audio;
  final Map<PrayerName, bool> enabledByPrayer;
  final Map<PrayerName, int> reminderMinutesByPrayer;
  final String localeCode;

  const SyncDailyAdhansParams({
    required this.prayerTimes,
    required this.enabledByPrayer,
    required this.reminderMinutesByPrayer,
    required this.localeCode,
    this.audio,
  });
}

class SyncDailyAdhans
    extends UseCase<Either<Failure, Unit>, SyncDailyAdhansParams> {
  final NotificationsRepository repository;
  SyncDailyAdhans({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(SyncDailyAdhansParams params) async {
    final adhanResult = await repository.scheduleDailyAdhans(
      prayerTimes: params.prayerTimes,
      audio: params.audio ?? AdhanAudioSettings.defaults(),
      enabledByPrayer: params.enabledByPrayer,
      localeCode: params.localeCode,
    );

    return adhanResult.fold(
      (failure) async => Left(failure),
      (_) => repository.schedulePrayerReminders(
        prayerTimes: params.prayerTimes,
        reminderMinutesByPrayer: params.reminderMinutesByPrayer,
        localeCode: params.localeCode,
      ),
    );
  }
}
