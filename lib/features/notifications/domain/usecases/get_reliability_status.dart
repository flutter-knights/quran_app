import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class GetReliabilityStatus
    extends UseCase<Either<Failure, ReliabilityStatus>, NoParams> {
  final NotificationsRepository repository;
  GetReliabilityStatus({required this.repository});

  @override
  Future<Either<Failure, ReliabilityStatus>> call(NoParams params) =>
      repository.getReliabilityStatus();
}
