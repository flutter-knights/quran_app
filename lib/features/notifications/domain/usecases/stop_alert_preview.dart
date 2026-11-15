import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class StopAlertPreview extends UseCase<Either<Failure, Unit>, NoParams> {
  final NotificationsRepository repository;
  StopAlertPreview({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(NoParams params) =>
      repository.stopPreview();
}
