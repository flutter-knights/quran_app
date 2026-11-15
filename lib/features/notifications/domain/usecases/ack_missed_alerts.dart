import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class AckMissedAlertsParams {
  final DateTime upTo;

  const AckMissedAlertsParams({required this.upTo});
}

class AckMissedAlerts
    extends UseCase<Either<Failure, Unit>, AckMissedAlertsParams> {
  final NotificationsRepository repository;
  AckMissedAlerts({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(AckMissedAlertsParams params) =>
      repository.ackMissedAlerts(upTo: params.upTo);
}
