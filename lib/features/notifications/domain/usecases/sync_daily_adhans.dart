import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class SyncDailyAdhansParams {
  final List<PrayerTimes> days;
  final AdhanAudioSettings? audio;
  final Map<PrayerName, bool> enabledByPrayer;
  final Map<PrayerName, int> reminderMinutesByPrayer;
  final String localeCode;

  const SyncDailyAdhansParams({
    required this.days,
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
      days: params.days,
      audio: params.audio ?? AdhanAudioSettings.defaults(),
      enabledByPrayer: params.enabledByPrayer,
      localeCode: params.localeCode,
    );

    return adhanResult.fold(
      (failure) async => Left(failure),
      (_) => repository.schedulePrayerReminders(
        days: params.days,
        reminderMinutesByPrayer: params.reminderMinutesByPrayer,
        localeCode: params.localeCode,
      ),
    );
  }
}
