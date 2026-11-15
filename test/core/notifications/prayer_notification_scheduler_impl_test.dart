import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler_impl.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

PrayerTimes _day(int day) {
  final key = '$day-11-2099';
  return PrayerTimes(
    key: key,
    timings: {
      PrayerName.fajr: '04:52',
      PrayerName.sunrise: '06:18',
      PrayerName.dhuhr: '11:41',
      PrayerName.asr: '14:39',
      PrayerName.maghrib: '16:58',
      PrayerName.isha: '18:16',
    },
    date: Date(
      month: '',
      weekDay: '',
      day: '$day',
      year: '',
      enMonth: '',
      enWeekDay: '',
      gregorianDate: key,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timezoneChannel = MethodChannel('flutter_timezone');
  late _MockPlugin plugin;
  late PrayerNotificationSchedulerImpl scheduler;

  final ishaOnly = {
    for (final p in alertPrayers)
      p: PrayerAlert(enabled: p == PrayerName.isha, reminderEnabled: true),
  };

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(tz.TZDateTime.utc(2099));
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (_) async => 'Etc/UTC');
    plugin = _MockPlugin();
    scheduler = PrayerNotificationSchedulerImpl(plugin: plugin);
    when(
      () => plugin.initialize(settings: any(named: 'settings')),
    ).thenAnswer((_) async => true);
    when(
      () => plugin.pendingNotificationRequests(),
    ).thenAnswer((_) async => []);
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, null),
  );

  void stubSchedule({bool Function(int id)? failWhen}) =>
      when(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        final id = invocation.namedArguments[#id] as int;
        if (failWhen?.call(id) ?? false) throw PlatformException(code: 'x');
      });

  test('scheduleAlerts before init throws a StateError', () async {
    await expectLater(
      scheduler.scheduleAlerts(
        days: [_day(15)],
        alerts: ishaOnly,
        localeCode: 'en',
      ),
      throwsStateError,
    );
    verifyNever(() => plugin.pendingNotificationRequests());
  });

  test('cancelAll clears both ranges and v1 ids, keeps the test id', () async {
    when(() => plugin.pendingNotificationRequests()).thenAnswer(
      (_) async => [
        for (final id in [
          0,
          10,
          15,
          20,
          25,
          119,
          120,
          199,
          200,
          319,
          320,
          9999,
        ])
          PendingNotificationRequest(id, null, null, null),
      ],
    );
    await scheduler.cancelAll();
    for (final id in [0, 10, 15, 20, 25, 119, 200, 319]) {
      verify(() => plugin.cancel(id: id)).called(1);
    }
    for (final id in [120, 199, 320, 9999]) {
      verifyNever(() => plugin.cancel(id: id));
    }
  });

  test('scheduleAlerts cancels first and returns the last adhan', () async {
    await scheduler.init();
    stubSchedule();
    final until = await scheduler.scheduleAlerts(
      days: [_day(15), _day(16)],
      alerts: ishaOnly,
      localeCode: 'en',
    );
    expect(until, DateTime(2099, 11, 16, 18, 16));
    verifyInOrder([
      () => plugin.pendingNotificationRequests(),
      () => plugin.zonedSchedule(
        id: 4,
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: 'Isha',
        body: "It's time for Isha prayer",
      ),
    ]);
    final details =
        verify(
              () => plugin.zonedSchedule(
                id: 204,
                scheduledDate: any(named: 'scheduledDate'),
                notificationDetails: captureAny(named: 'notificationDetails'),
                androidScheduleMode: any(named: 'androidScheduleMode'),
                title: any(named: 'title'),
                body: any(named: 'body'),
              ),
            ).captured.single
            as NotificationDetails;
    expect(details.iOS?.presentSound, isTrue);
    expect(details.iOS?.sound, isNull);
  });

  test('the adhan clip goes into the iOS details', () async {
    await scheduler.init();
    stubSchedule();
    await scheduler.scheduleAlerts(
      days: [_day(15)],
      alerts: {PrayerName.fajr: const PrayerAlert()},
      localeCode: 'en',
    );
    final details =
        verify(
              () => plugin.zonedSchedule(
                id: 0,
                scheduledDate: any(named: 'scheduledDate'),
                notificationDetails: captureAny(named: 'notificationDetails'),
                androidScheduleMode: any(named: 'androidScheduleMode'),
                title: any(named: 'title'),
                body: any(named: 'body'),
              ),
            ).captured.single
            as NotificationDetails;
    expect(details.iOS?.sound, 'fajr_adhan.caf');
    expect(details.iOS?.presentSound, isTrue);
  });

  test('lastAdhan ignores reminders and failed adhans', () async {
    await scheduler.init();
    stubSchedule(failWhen: (id) => id < 200);
    final until = await scheduler.scheduleAlerts(
      days: [_day(15)],
      alerts: ishaOnly,
      localeCode: 'en',
    );
    expect(until, isNull);
    verify(
      () => plugin.zonedSchedule(
        id: 204,
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).called(1);
  });
}
