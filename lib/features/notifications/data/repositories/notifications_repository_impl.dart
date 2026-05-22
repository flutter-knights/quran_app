import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsNativeDataSource native;
  final PrayerNotificationScheduler legacyScheduler;

  NotificationsRepositoryImpl({
    required this.native,
    required this.legacyScheduler,
  });

  Future<Either<Failure, Unit>> _run(Future<void> Function() body) async {
    try {
      await body();
      return const Right(unit);
    } on PlatformNotImplementedException {
      return const Left(PlatformNotSupportedFailure(
        'Pinned prayer strip is not implemented on this platform yet.',
      ));
    } catch (e) {
      return Left(UnknownNotificationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state) =>
      _run(() => native.enableStrip(state));

  @override
  Future<Either<Failure, Unit>> disableStrip() =>
      _run(() => native.disableStrip());

  @override
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state) =>
      _run(() => native.refreshStrip(state));

  @override
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
  }) =>
      // Plan A: `audio` is dropped because the legacy scheduler has no audio
      // concept. Plan B will route audio through `native.scheduleDailyAdhans`.
      _run(() => legacyScheduler.scheduleDailyPrayerNotifications(prayerTimes));

  @override
  Future<Either<Failure, Unit>> cancelAllAdhans() =>
      _run(() => legacyScheduler.cancelAllPrayerNotifications());
}
