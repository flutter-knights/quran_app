import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/data/services/ios_alert_plan.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationSchedulerImpl implements PrayerNotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  PrayerNotificationSchedulerImpl({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _fajrChannelId = 'prayer_fajr_channel';
  static const String _standardChannelId = 'prayer_standard_channel';
  static const String _legacyChannelId = 'prayer_times_channel';

  @override
  Future<bool?> requestNotificationsPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return androidPlugin.requestNotificationsPermission();
    }
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return iosPlugin?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = await iosPlugin?.checkPermissions().then(
      (p) => p?.isAlertEnabled,
    );
    return granted ?? false;
  }

  @override
  Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_alfurqan'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // One-time migration: drop the legacy single-sound channel. No-op if absent.
    await androidPlugin?.deleteNotificationChannel(channelId: _legacyChannelId);
    await androidPlugin?.deleteNotificationChannel(channelId: _fajrChannelId);
    await androidPlugin?.deleteNotificationChannel(
      channelId: _standardChannelId,
    );

    _initialized = true;
    debugPrint('[PrayerNotif] init complete, tz=${tz.local.name}');
  }

  @override
  Future<DateTime?> scheduleAlerts({
    required List<PrayerTimes> days,
    required Map<PrayerName, PrayerAlert> alerts,
    required String localeCode,
  }) async {
    if (!_initialized) throw StateError('scheduleAlerts called before init');
    await cancelAll();
    final requests = planIosAlerts(
      days: days,
      alerts: alerts,
      localeCode: localeCode,
      now: DateTime.now(),
    );
    DateTime? lastAdhan;
    var scheduled = 0;
    for (final request in requests) {
      try {
        await _plugin.zonedSchedule(
          id: request.id,
          title: request.title,
          body: request.body,
          scheduledDate: tz.TZDateTime.from(request.at, tz.local),
          notificationDetails: _details(request.sound),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        scheduled++;
        if (!request.isReminder &&
            (lastAdhan == null || request.at.isAfter(lastAdhan))) {
          lastAdhan = request.at;
        }
      } catch (e) {
        debugPrint('[PrayerNotif] schedule failed for id=${request.id}: $e');
      }
    }
    debugPrint(
      '[PrayerNotif] scheduled $scheduled of ${requests.length}, '
      'last adhan $lastAdhan',
    );
    return lastAdhan;
  }

  @override
  Future<void> cancelAll() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (isIosAlertId(request.id)) await _plugin.cancel(id: request.id);
    }
  }

  @override
  Future<void> scheduleTestNotification({
    required PrayerAlert alert,
    required String localeCode,
    Duration delay = const Duration(seconds: 30),
  }) async {
    if (!_initialized) {
      debugPrint('[PrayerNotif] test called before init — skipping');
      return;
    }
    final fireAt = tz.TZDateTime.now(tz.local).add(delay);
    final request = planIosTestAlert(
      alert: alert,
      localeCode: localeCode,
      at: fireAt,
    );
    await _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: fireAt,
      notificationDetails: _details(request.sound),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[PrayerNotif] test scheduled at $fireAt');
  }

  NotificationDetails _details(IosSound sound) => NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: sound.audible,
      sound: sound.file,
    ),
  );
}
