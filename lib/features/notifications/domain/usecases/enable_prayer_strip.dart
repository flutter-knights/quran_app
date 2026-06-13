import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class EnablePrayerStripParams {
  final PrayerStripWindow window;
  const EnablePrayerStripParams({required this.window});
}

class EnablePrayerStrip
    extends UseCase<Either<Failure, Unit>, EnablePrayerStripParams> {
  final NotificationsRepository repository;
  EnablePrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(EnablePrayerStripParams params) =>
      repository.enableStrip(params.window);
}
