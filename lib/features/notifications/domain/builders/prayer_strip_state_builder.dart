import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// Fixed Fajr→Isha render order. Independent of localization.
const _renderOrder = <PrayerName>[
  PrayerName.fajr,
  PrayerName.sunrise,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];

const _labelsAr = <PrayerName, String>{
  PrayerName.fajr: 'الفجر',
  PrayerName.sunrise: 'الشروق',
  PrayerName.dhuhr: 'الظهر',
  PrayerName.asr: 'العصر',
  PrayerName.maghrib: 'المغرب',
  PrayerName.isha: 'العشاء',
};

const _labelsEn = <PrayerName, String>{
  PrayerName.fajr: 'Fajr',
  PrayerName.sunrise: 'Sunrise',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

const _jumuahLabelAr = 'الجمعة';
const _jumuahLabelEn = "Jum'ah";

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
    int? accentColor,
  }) {
    final labels = localeCode == 'ar' ? _labelsAr : _labelsEn;
    final jumuah = localeCode == 'ar' ? _jumuahLabelAr : _jumuahLabelEn;

    final cells = _renderOrder.map((p) {
      final rawLabel = labels[p]!;
      final label = (isFriday && p == PrayerName.dhuhr) ? jumuah : rawLabel;
      final raw = prayerTimes.timings[p] ?? '';
      final time = use24Hour
          ? raw.toIndicNumerals(localeCode)
          : _format12Hour(raw, localeCode);
      return PrayerCell(label: label, timeFormatted: time);
    }).toList();

    final nextIndex = _renderOrder.indexOf(nextPrayer);

    final monthName =
        localeCode == 'ar' ? prayerTimes.date.month : prayerTimes.date.enMonth;
    final dayPart = prayerTimes.date.day.toIndicNumerals(localeCode);
    final hijriLabel = '$dayPart $monthName';

    final weekdayLabel =
        localeCode == 'ar' ? prayerTimes.date.weekDay : prayerTimes.date.enWeekDay;

    return PrayerStripState(
      cells: cells,
      nextPrayerIndex: nextIndex < 0 ? 0 : nextIndex,
      hijriDateLabel: hijriLabel,
      weekdayLabel: weekdayLabel,
      localeCode: localeCode,
      isFriday: isFriday,
      accentColor: accentColor,
    );
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
