import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class ScheduleTestAdhanParams {
  final PrayerAlert alert;
  final String localeCode;

  const ScheduleTestAdhanParams({
    required this.alert,
    required this.localeCode,
  });
}

class ScheduleTestAdhan
    extends UseCase<Either<Failure, Unit>, ScheduleTestAdhanParams> {
  final NotificationsRepository repository;
  ScheduleTestAdhan({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(ScheduleTestAdhanParams params) =>
      repository.scheduleTestAdhan(
        alert: params.alert,
        localeCode: params.localeCode,
      );
}
