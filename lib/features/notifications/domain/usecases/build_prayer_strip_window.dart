import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';

class BuildPrayerStripWindowParams {
  final String localeCode;
  final bool use24Hour;
  final int? accentColor;
  final DateTime? now;
  final int days;

  const BuildPrayerStripWindowParams({
    required this.localeCode,
    required this.use24Hour,
    this.accentColor,
    this.now,
    this.days = 7,
  });
}

/// Assembles a bounded window of strip day-states from the locally cached
/// month. Stops at the first day with no cached prayer times, and returns null
/// when not even today is cached (caller then skips posting the strip).
class BuildPrayerStripWindow {
  final PrayerTimesRepository prayerTimesRepository;

  BuildPrayerStripWindow({required this.prayerTimesRepository});

  Future<PrayerStripWindow?> call(BuildPrayerStripWindowParams params) async {
    final now = params.now ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final states = <PrayerStripState>[];

    for (var i = 0; i < params.days; i++) {
      final date = DateTime(today.year, today.month, today.day + i);
      final pt = await prayerTimesRepository.getCachedForDate(date);
      if (pt == null) break; // stop at the first gap

      // Today resolves "next" against the live clock; future days against
      // their own start so they open on Fajr.
      final resolveAt = i == 0 ? now : date;
      final nextPrayer =
          NextPrayerResolver.resolve(timings: pt.timings, now: resolveAt);

      states.add(PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: nextPrayer,
        localeCode: params.localeCode,
        isFriday: date.weekday == DateTime.friday,
        use24Hour: params.use24Hour,
        accentColor: params.accentColor,
      ));
    }

    if (states.isEmpty) return null;
    return PrayerStripWindow(days: states);
  }
}
