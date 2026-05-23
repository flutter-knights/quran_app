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
/// service as `HH:mm` 24-hour strings; the builder applies Arabic-Indic
/// numeral conversion for `localeCode == 'ar'` but does **not** apply the
/// user's 12-hour preference. (The strip always shows 24-hour times, matching
/// the reference design.)
class PrayerStripStateBuilder {
  const PrayerStripStateBuilder._();

  static PrayerStripState build({
    required PrayerTimes prayerTimes,
    required PrayerName nextPrayer,
    required String localeCode,
    required bool isFriday,
  }) {
    final labels = localeCode == 'ar' ? _labelsAr : _labelsEn;
    final jumuah = localeCode == 'ar' ? _jumuahLabelAr : _jumuahLabelEn;

    final cells = _renderOrder.map((p) {
      final rawLabel = labels[p]!;
      final label = (isFriday && p == PrayerName.dhuhr) ? jumuah : rawLabel;
      final time = (prayerTimes.timings[p] ?? '').toIndicNumerals(localeCode);
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
    );
  }
}
