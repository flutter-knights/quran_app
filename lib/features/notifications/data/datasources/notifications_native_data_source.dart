import 'package:flutter/services.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

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
  Future<void> enableStrip(PrayerStripState state);
  Future<void> disableStrip();
  Future<void> refreshStrip(PrayerStripState state);
  Future<void> scheduleDailyAdhans({
    required Map<String, String> timingsByPrayer,
    required Map<String, String> clipAssetByPrayer,
    required double volume,
  });
  Future<void> cancelAllAdhans();
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
  Future<void> enableStrip(PrayerStripState state) =>
      _invoke('enableStrip', state.toJson());

  @override
  Future<void> disableStrip() => _invoke('disableStrip');

  @override
  Future<void> refreshStrip(PrayerStripState state) =>
      _invoke('refreshStrip', state.toJson());

  @override
  Future<void> scheduleDailyAdhans({
    required Map<String, String> timingsByPrayer,
    required Map<String, String> clipAssetByPrayer,
    required double volume,
  }) =>
      _invoke('scheduleDailyAdhans', {
        'timings': timingsByPrayer,
        'clips': clipAssetByPrayer,
        'volume': volume,
      });

  @override
  Future<void> cancelAllAdhans() => _invoke('cancelAllAdhans');
}
