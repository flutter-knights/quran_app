import 'package:quran_app/core/constants/prayer_name.dart';

/// Picks which prayer is "next" given a snapshot of today's timings and
/// the current wall-clock time. Pure Dart; no Flutter dependency.
class NextPrayerResolver {
  const NextPrayerResolver._();

  static const _order = <PrayerName>[
    PrayerName.fajr,
    PrayerName.sunrise,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  /// Returns the first prayer whose time is strictly greater than [now].
  /// Wraps to [PrayerName.fajr] when all of today's prayers have passed,
  /// or when [timings] is empty / unparseable.
  ///
  /// When [skipSunrise] is `true`, [PrayerName.sunrise] is never returned as
  /// the "next" prayer — the resolver skips it and moves on to the next
  /// candidate. Defaults to `false` (sunrise is a valid next prayer).
  static PrayerName resolve({
    required Map<PrayerName, String> timings,
    required DateTime now,
    bool skipSunrise = false,
  }) {
    final nowMinutes = now.hour * 60 + now.minute;
    for (final p in _order) {
      if (skipSunrise && p == PrayerName.sunrise) continue;
      final raw = timings[p];
      if (raw == null) continue;
      final minutes = _parseHHmm(raw);
      if (minutes == null) continue;
      if (minutes > nowMinutes) return p;
    }
    return PrayerName.fajr;
  }

  static int? _parseHHmm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
