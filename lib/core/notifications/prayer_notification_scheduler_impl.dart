import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationSchedulerImpl implements PrayerNotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  PrayerNotificationSchedulerImpl({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const Map<PrayerName, int> _notificationIds = {
    PrayerName.fajr: 10,
    // 11 reserved for sunrise (not scheduled — sunrise has no adhan)
    PrayerName.dhuhr: 12,
    PrayerName.asr: 13,
    PrayerName.maghrib: 14,
    PrayerName.isha: 15,
  };

  static const Map<PrayerName, String> _prayerTitles = {
    PrayerName.fajr: 'Fajr',
    PrayerName.dhuhr: 'Dhuhr',
    PrayerName.asr: 'Asr',
    PrayerName.maghrib: 'Maghrib',
    PrayerName.isha: 'Isha',
  };

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_times_channel',
      'Prayer Times',
      channelDescription: 'Adhan at prayer times',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('adhan'),
      playSound: true,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      sound: 'adhan.mp3',
      presentSound: true,
      presentAlert: true,
      presentBadge: false,
    ),
  );

  @override
  Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings: initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }

  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes) async {
    if (!_initialized) {
      throw StateError(
        'PrayerNotificationSchedulerImpl.init() must be called before scheduling',
      );
    }

    await cancelAllPrayerNotifications();
    final date = DateFormat('dd-MM-yyyy').parse(prayerTimes.date.gregorianDate);
    final now = DateTime.now();

    for (final entry in _notificationIds.entries) {
      final prayerName = entry.key;
      final notificationId = entry.value;
      final timeStr = prayerTimes.timings[prayerName];
      if (timeStr == null) continue;

      try {
        final parts = timeStr.split(':');
        final scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        if (scheduledTime.isBefore(now)) continue;

        await _plugin.zonedSchedule(
          id: notificationId,
          title: _prayerTitles[prayerName],
          body: 'Time for ${_prayerTitles[prayerName]} prayer',
          scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // skip this prayer on malformed data
        continue;
      }
    }
  }

  @override
  Future<void> cancelAllPrayerNotifications() async {
    for (final id in _notificationIds.values) {
      await _plugin.cancel(id: id);
    }
  }
}
