import 'dart:math';

import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_render_style.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';

class BuildPrayerStripWindowParams {
  final String localeCode;
  final bool use24Hour;
  final DateTime? now;
  final int days;
  final List<PrayerTimes> cachedDays;
  final String Function(String prayerLabel)? nextInLabel;
  final String nextTag;
  final StripRenderStyle? style;

  const BuildPrayerStripWindowParams({
    required this.localeCode,
    required this.use24Hour,
    this.now,
    this.days = 7,
    required this.cachedDays,
    this.nextInLabel,
    this.nextTag = '',
    this.style,
  });
}

/// Assembles a bounded window of strip day-states from the locally cached
/// month. Stops at the first day with no cached prayer times, and returns null
/// when not even today is cached (caller then skips posting the strip).
class BuildPrayerStripWindow {
  Future<PrayerStripWindow?> call(BuildPrayerStripWindowParams params) async {
    final now = params.now ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final states = <PrayerStripState>[];

    final count = min(params.days, params.cachedDays.length);
    for (var i = 0; i < count; i++) {
      final date = DateTime(today.year, today.month, today.day + i);
      final pt = params.cachedDays[i];

      // Today resolves "next" against the live clock; future days against
      // their own start so they open on Fajr.
      final resolveAt = i == 0 ? now : date;
      final nextPrayer = NextPrayerResolver.resolve(
        timings: pt.timings,
        now: resolveAt,
      );

      states.add(
        PrayerStripStateBuilder.build(
          prayerTimes: pt,
          nextPrayer: nextPrayer,
          localeCode: params.localeCode,
          isFriday: date.weekday == DateTime.friday,
          use24Hour: params.use24Hour,
          nextInLabel: params.nextInLabel,
          nextTag: params.nextTag,
        ),
      );
    }

    if (states.isEmpty) return null;
    return PrayerStripWindow(days: states, style: params.style);
  }
}
