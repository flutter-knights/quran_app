import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class GetAndroidSdkInt extends UseCase<Either<Failure, int?>, NoParams> {
  final NotificationsRepository repository;
  GetAndroidSdkInt({required this.repository});

  @override
  Future<Either<Failure, int?>> call(NoParams params) =>
      repository.androidSdkInt();
}
