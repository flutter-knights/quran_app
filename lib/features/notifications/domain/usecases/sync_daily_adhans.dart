import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class SyncDailyAdhansParams {
  final List<PrayerTimes> days;
  final Map<PrayerName, PrayerAlert> alerts;
  final String localeCode;

  const SyncDailyAdhansParams({
    required this.days,
    required this.alerts,
    required this.localeCode,
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
      alerts: params.alerts,
      localeCode: params.localeCode,
    );

    return adhanResult.fold(
      (failure) async => Left(failure),
      (_) => repository.schedulePrayerReminders(
        days: params.days,
        alerts: params.alerts,
        localeCode: params.localeCode,
      ),
    );
  }
}
