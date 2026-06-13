import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class RefreshPrayerStripParams {
  final PrayerStripWindow window;
  const RefreshPrayerStripParams({required this.window});
}

class RefreshPrayerStrip
    extends UseCase<Either<Failure, Unit>, RefreshPrayerStripParams> {
  final NotificationsRepository repository;
  RefreshPrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(RefreshPrayerStripParams params) =>
      repository.refreshStrip(params.window);
}
