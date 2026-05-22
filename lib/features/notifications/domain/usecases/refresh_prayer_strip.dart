import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class RefreshPrayerStripParams {
  final PrayerStripState state;
  const RefreshPrayerStripParams({required this.state});
}

class RefreshPrayerStrip
    extends UseCase<Either<Failure, Unit>, RefreshPrayerStripParams> {
  final NotificationsRepository repository;
  RefreshPrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(RefreshPrayerStripParams params) =>
      repository.refreshStrip(params.state);
}
