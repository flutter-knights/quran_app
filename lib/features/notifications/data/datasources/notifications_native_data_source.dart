import 'package:flutter/services.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';

/// Thrown when the native side has not registered a handler for a channel
/// method. The repository maps this to `PlatformNotSupportedFailure`.
class PlatformNotImplementedException implements Exception {
  final String method;
  const PlatformNotImplementedException(this.method);
  @override
  String toString() =>
      'PlatformNotImplementedException: no native handler for "$method"';
}

abstract class NotificationsNativeDataSource {
  Future<void> enableStrip(PrayerStripWindow window);
  Future<void> disableStrip();
  Future<void> refreshStrip(PrayerStripWindow window);
  Future<void> scheduleDailyAdhans({
    required List<Map<String, dynamic>> days,
    required Map<String, Map<String, Object>> alerts,
    required String localeCode,
  });
  Future<void> cancelAllAdhans();
  Future<void> schedulePrayerReminders({
    required List<Map<String, dynamic>> days,
    required Map<String, Map<String, Object>> reminders,
    required String localeCode,
  });
  Future<void> cancelAllReminders();

  /// Debug-only. Fires a one-off adhan `delay` from now via the native pipeline.
  Future<void> scheduleTestAdhan({
    Duration delay = const Duration(seconds: 30),
    String localeCode = 'en',
    required String sound,
    required bool ringInSilent,
  });
  Future<Map<String, Object?>> getReliabilityStatus();
  Future<void> ackMissed({required int upTo});
  Future<void> openSystemSettings(String target);
  Future<void> previewSound({required String sound, required String prayer});
  Future<void> stopPreview();
}

class NotificationsNativeDataSourceImpl
    implements NotificationsNativeDataSource {
  static const channelName = 'quran_app/notifications';
  static const MethodChannel _channel = MethodChannel(channelName);

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      throw PlatformNotImplementedException(method);
    }
  }

  @override
  Future<void> enableStrip(PrayerStripWindow window) =>
      _invoke('enableStrip', window.toJson());

  @override
  Future<void> disableStrip() => _invoke('disableStrip');

  @override
  Future<void> refreshStrip(PrayerStripWindow window) =>
      _invoke('refreshStrip', window.toJson());

  @override
  Future<void> scheduleDailyAdhans({
    required List<Map<String, dynamic>> days,
    required Map<String, Map<String, Object>> alerts,
    required String localeCode,
  }) => _invoke('scheduleDailyAdhans', {
    'days': days,
    'alerts': alerts,
    'localeCode': localeCode,
  });

  @override
  Future<void> cancelAllAdhans() => _invoke('cancelAllAdhans');

  @override
  Future<void> schedulePrayerReminders({
    required List<Map<String, dynamic>> days,
    required Map<String, Map<String, Object>> reminders,
    required String localeCode,
  }) => _invoke('schedulePrayerReminders', {
    'days': days,
    'reminders': reminders,
    'localeCode': localeCode,
  });

  @override
  Future<void> cancelAllReminders() => _invoke('cancelAllReminders');

  @override
  Future<void> scheduleTestAdhan({
    Duration delay = const Duration(seconds: 30),
    String localeCode = 'en',
    required String sound,
    required bool ringInSilent,
  }) => _invoke('scheduleTestAdhan', {
    'delaySeconds': delay.inSeconds,
    'localeCode': localeCode,
    'sound': sound,
    'ringInSilent': ringInSilent,
  });

  @override
  Future<Map<String, Object?>> getReliabilityStatus() async {
    try {
      return await _channel.invokeMapMethod<String, Object?>(
            'getReliabilityStatus',
          ) ??
          {};
    } on MissingPluginException {
      throw const PlatformNotImplementedException('getReliabilityStatus');
    }
  }

  @override
  Future<void> ackMissed({required int upTo}) =>
      _invoke('ackMissed', {'upTo': upTo});

  @override
  Future<void> openSystemSettings(String target) =>
      _invoke('openSystemSettings', {'target': target});

  @override
  Future<void> previewSound({required String sound, required String prayer}) =>
      _invoke('previewSound', {'sound': sound, 'prayer': prayer});

  @override
  Future<void> stopPreview() => _invoke('stopPreview');
}
