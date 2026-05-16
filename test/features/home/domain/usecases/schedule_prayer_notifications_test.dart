import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/usecases/schedule_prayer_notifications.dart';

class MockPrayerNotificationScheduler extends Mock
    implements PrayerNotificationScheduler {}

void main() {
  late MockPrayerNotificationScheduler mockScheduler;
  late SchedulePrayerNotifications useCase;

  final fakePrayerTimes = PrayerTimes(
    key: '13-05-2026',
    timings: {
      PrayerName.fajr: '04:30',
      PrayerName.sunrise: '06:00',
      PrayerName.dhuhr: '12:00',
      PrayerName.asr: '15:30',
      PrayerName.maghrib: '18:45',
      PrayerName.isha: '20:15',
    },
    date: Date(
      month: 'Dhul-Qidah',
      weekDay: 'Wednesday',
      day: '15',
      year: '1447',
      enMonth: 'November',
      enWeekDay: 'Wednesday',
      gregorianDate: '13-05-2026',
    ),
  );

  setUp(() {
    mockScheduler = MockPrayerNotificationScheduler();
    useCase = SchedulePrayerNotifications(scheduler: mockScheduler);
  });

  test('delegates to scheduler with the correct PrayerTimes', () async {
    when(
      () => mockScheduler.scheduleDailyPrayerNotifications(fakePrayerTimes),
    ).thenAnswer((_) async {});

    await useCase(
      SchedulePrayerNotificationsParams(prayerTimes: fakePrayerTimes),
    );

    verify(
      () => mockScheduler.scheduleDailyPrayerNotifications(fakePrayerTimes),
    ).called(1);
  });
}
