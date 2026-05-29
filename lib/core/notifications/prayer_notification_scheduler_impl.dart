import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
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

  static const Map<PrayerName, int> _reminderIds = {
    PrayerName.fajr: 20,
    PrayerName.dhuhr: 22,
    PrayerName.asr: 23,
    PrayerName.maghrib: 24,
    PrayerName.isha: 25,
  };

  static const Map<PrayerName, String> _prayerTitles = {
    PrayerName.fajr: 'Fajr',
    PrayerName.dhuhr: 'Dhuhr',
    PrayerName.asr: 'Asr',
    PrayerName.maghrib: 'Maghrib',
    PrayerName.isha: 'Isha',
  };

  static const String _fajrChannelId = 'prayer_fajr_channel';
  static const String _standardChannelId = 'prayer_standard_channel';
  static const String _legacyChannelId = 'prayer_times_channel';

  static const AndroidNotificationChannel _fajrChannel =
      AndroidNotificationChannel(
    _fajrChannelId,
    'Fajr adhan',
    description: 'Adhan at prayer time',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('fajr_adhan'),
    playSound: true,
    enableVibration: false,
  );

  static const AndroidNotificationChannel _standardChannel =
      AndroidNotificationChannel(
    _standardChannelId,
    'Prayer adhan',
    description: 'Adhan at prayer time',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('normal_adhan'),
    playSound: true,
    enableVibration: false,
  );

  static const NotificationDetails _fajrDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _fajrChannelId,
      'Fajr adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('fajr_adhan'),
      playSound: true,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      sound: 'fajr_adhan.caf',
      presentSound: true,
      presentAlert: true,
      presentBadge: false,
    ),
  );

  static const NotificationDetails _standardDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _standardChannelId,
      'Prayer adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('normal_adhan'),
      playSound: true,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      sound: 'normal_adhan.caf',
      presentSound: true,
      presentAlert: true,
      presentBadge: false,
    ),
  );

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_reminder_channel',
      'Pre-prayer reminders',
      channelDescription: 'Notifies you a few minutes before each prayer',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: false,
      presentAlert: true,
      presentBadge: false,
    ),
  );

  NotificationDetails _detailsFor(PrayerName p) =>
      p == PrayerName.fajr ? _fajrDetails : _standardDetails;

  @override
  Future<bool?> requestNotificationsPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      return androidPlugin.requestNotificationsPermission();
    }
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    return iosPlugin?.requestPermissions(alert: true, badge: false, sound: true);
  }

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

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // One-time migration: drop the legacy single-sound channel. No-op if absent.
    await androidPlugin?.deleteNotificationChannel(channelId: _legacyChannelId);
    await androidPlugin?.createNotificationChannel(_fajrChannel);
    await androidPlugin?.createNotificationChannel(_standardChannel);

    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[PrayerNotif] init complete, tz=${tz.local.name}');
  }

  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      debugPrint(
        '[PrayerNotif] Android: legacy path is intentionally inert (handled '
        'natively via AdhanScheduler). Call site should branch by platform.',
      );
      return;
    }
    if (!_initialized) {
      debugPrint('[PrayerNotif] schedule called before init — skipping');
      return;
    }

    await cancelAllPrayerNotifications();
    final date = prayerTimes.date.gregorianDate.gregorianDate();
    final now = DateTime.now();
    debugPrint('[PrayerNotif] scheduling for date=$date, now=$now');

    var scheduled = 0;
    var skipped = 0;
    for (final entry in _notificationIds.entries) {
      final prayerName = entry.key;
      final notificationId = entry.value;
      final timeStr = prayerTimes.timings[prayerName];
      if (timeStr == null) {
        skipped++;
        continue;
      }

      try {
        final parts = timeStr.split(':');
        final scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        if (scheduledTime.isBefore(now)) {
          skipped++;
          continue;
        }

        await _plugin.zonedSchedule(
          id: notificationId,
          title: _prayerTitles[prayerName],
          body: 'Time for ${_prayerTitles[prayerName]} prayer',
          scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails: _detailsFor(prayerName),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        scheduled++;
        debugPrint(
          '[PrayerNotif] scheduled $prayerName id=$notificationId at $scheduledTime',
        );
      } catch (e) {
        skipped++;
        debugPrint('[PrayerNotif] schedule failed for $prayerName: $e');
        continue;
      }
    }
    debugPrint(
      '[PrayerNotif] done: scheduled=$scheduled, skipped=$skipped',
    );
  }

  @override
  Future<void> cancelAllPrayerNotifications() async {
    for (final id in _notificationIds.values) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> scheduleTestNotification({
    Duration delay = const Duration(seconds: 30),
  }) async {
    if (!_initialized) {
      debugPrint('[PrayerNotif] test called before init — skipping');
      return;
    }
    final fireAt = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      id: 9999,
      title: 'Adhan test',
      body: 'Background fire check (${delay.inSeconds}s)',
      scheduledDate: fireAt,
      notificationDetails: _standardDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[PrayerNotif] test scheduled at $fireAt');
  }

  @override
  Future<void> scheduleStaticReminder({
    required PrayerName prayer,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      debugPrint('[PrayerNotif] reminder before init — skipping');
      return;
    }
    final id = _reminderIds[prayer];
    if (id == null) return;
    if (at.isBefore(DateTime.now())) {
      debugPrint('[PrayerNotif] reminder for $prayer in the past — skipping');
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[PrayerNotif] reminder scheduled for $prayer at $at');
  }

  @override
  Future<void> cancelAllStaticReminders() async {
    for (final id in _reminderIds.values) {
      await _plugin.cancel(id: id);
    }
  }
}
