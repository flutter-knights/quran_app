import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/services/prayer_labels.dart';

/// Fixed Fajr→Isha render order (5 prayers; sunrise is excluded).
/// Independent of localization.
const _renderOrder = <PrayerName>[
  PrayerName.fajr,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];

/// Builds a [PrayerStripState] snapshot from today's prayer times.
///
/// Pure Dart — no Flutter dependency. Time strings come from the prayer-times
/// service as `HH:mm` 24-hour strings. The builder honors the user's hour-format
/// preference via [use24Hour]: when `false`, times are rendered as 12-hour
/// digits without an AM/PM (or ص/م) suffix to keep the notification compact.
/// Arabic-Indic numeral conversion is applied for `localeCode == 'ar'` in
/// either format.
class PrayerStripStateBuilder {
  const PrayerStripStateBuilder._();

  static PrayerStripState build({
    required PrayerTimes prayerTimes,
    required PrayerName nextPrayer,
    required String localeCode,
    required bool isFriday,
    required bool use24Hour,
    String Function(String prayerLabel)? nextInLabel,
  }) {
    final cells = _renderOrder.map((p) {
      final label = prayerNameLabel(
        p,
        arabic: localeCode == 'ar',
        friday: isFriday,
      );
      final raw = prayerTimes.timings[p] ?? '';
      final time = use24Hour
          ? raw.toIndicNumerals(localeCode)
          : _format12Hour(raw, localeCode);
      final suffix = use24Hour ? null : _dayPeriod(raw, localeCode);
      return PrayerCell(
        label: label,
        timeFormatted: time,
        timeFull: suffix == null ? time : '$time $suffix',
        minutes: _parseMinutes(raw),
        nextLabel: nextInLabel?.call(label) ?? '',
      );
    }).toList();

    final nextIndex = _renderOrder.indexOf(nextPrayer);

    final monthName = localeCode == 'ar'
        ? prayerTimes.date.month
        : prayerTimes.date.enMonth;
    final dayPart = prayerTimes.date.day.toIndicNumerals(localeCode);
    final hijriLabel = '$dayPart $monthName';

    final weekdayLabel = localeCode == 'ar'
        ? prayerTimes.date.weekDay
        : prayerTimes.date.enWeekDay;

    return PrayerStripState(
      cells: cells,
      nextPrayerIndex: nextIndex < 0 ? 0 : nextIndex,
      dateKey: prayerTimes.date.gregorianDate,
      hijriDateLabel: hijriLabel,
      weekdayLabel: weekdayLabel,
      localeCode: localeCode,
      isFriday: isFriday,
    );
  }

  /// Parses a `HH:mm` 24-hour string to minutes-from-midnight. Returns 0 on a
  /// malformed input (the cell still renders; it just sorts to the top).
  static int _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String? _dayPeriod(String hhmm24, String localeCode) {
    final h = int.tryParse(hhmm24.split(':').first);
    if (h == null || h < 0 || h > 23) return null;
    final ar = localeCode == 'ar';
    if (h < 12) return ar ? 'ص' : 'AM';
    return ar ? 'م' : 'PM';
  }

  /// Converts a `HH:mm` 24-hour string into a 12-hour string without an
  /// AM/PM suffix (the strip is too tight to spare 3+ characters per cell).
  /// Falls back to the input (with locale numerals applied) if the input
  /// cannot be parsed.
  static String _format12Hour(String hhmm24, String localeCode) {
    final parts = hhmm24.split(':');
    if (parts.length != 2) return hhmm24.toIndicNumerals(localeCode);
    final h = int.tryParse(parts[0]);
    final m = parts[1];
    if (h == null || h < 0 || h > 23) {
      return hhmm24.toIndicNumerals(localeCode);
    }
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    final hStr = h12.toString().padLeft(2, '0');
    return '$hStr:$m'.toIndicNumerals(localeCode);
  }
}
