import 'package:hive/hive.dart';

/// Builds a stable string describing every input that determines prayer times.
/// Coordinates are rounded to 1 decimal place (~11 km) so ordinary commuting
/// jitter does not trigger a full-month refetch (prayer-time deltas at that
/// scale are seconds), while genuine relocations do.
String buildPrayerConfigSignature({
  required double latitude,
  required double longitude,
  required int method,
  required int school,
}) {
  final lat = latitude.toStringAsFixed(1);
  final lon = longitude.toStringAsFixed(1);
  return '${lat}_${lon}_${method}_$school';
}

/// Persists the last-used signature; reports whether it changed.
class PrayerConfigSignatureStore {
  PrayerConfigSignatureStore({required this.box});
  final Box box;
  static const _key = 'prayer_config_signature';

  /// Returns true when [signature] differs from the stored one (or none is
  /// stored), and stores the new value. Returns false when unchanged.
  bool hasChangedAndStore(String signature) {
    final prev = box.get(_key) as String?;
    if (prev == signature) return false;
    box.put(_key, signature);
    return true;
  }
}
