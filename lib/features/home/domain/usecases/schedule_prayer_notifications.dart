import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class SchedulePrayerNotificationsParams {
  final PrayerTimes prayerTimes;
  const SchedulePrayerNotificationsParams({required this.prayerTimes});
}

class SchedulePrayerNotifications
    extends UseCase<void, SchedulePrayerNotificationsParams> {
  final PrayerNotificationScheduler scheduler;

  SchedulePrayerNotifications({required this.scheduler});

  @override
  Future<void> call(SchedulePrayerNotificationsParams params) =>
      scheduler.scheduleDailyPrayerNotifications(params.prayerTimes);
}
