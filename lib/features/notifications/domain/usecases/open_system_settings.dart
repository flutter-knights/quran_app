import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class OpenSystemSettings
    extends UseCase<Either<Failure, Unit>, SystemSettingsTarget> {
  final NotificationsRepository repository;
  OpenSystemSettings({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(SystemSettingsTarget params) =>
      repository.openSystemSettings(params);
}
