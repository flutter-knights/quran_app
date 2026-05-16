import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/generated/l10n.dart';

export 'package:quran_app/core/constants/prayer_name.dart';

class PrayerData<T1, T2> {
  final T1 prayerName;
  final T2 prayerIcon;

  PrayerData({required this.prayerName, required this.prayerIcon});
}

const prayersList = [
  PrayerName.fajr,
  PrayerName.sunrise,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];

Map<PrayerName, PrayerData> get prayersMap => {
  PrayerName.fajr: PrayerData(
    prayerName: S.current.fajr,
    prayerIcon: AssetsDir.iconsDir('icon_dawn.svg'),
  ),
  PrayerName.sunrise: PrayerData(
    prayerName: S.current.sunrise,
    prayerIcon: AssetsDir.iconsDir('icon_sunrise.svg'),
  ),

  PrayerName.dhuhr: PrayerData(
    prayerName: S.current.dhuhr,
    prayerIcon: AssetsDir.iconsDir('icon_sun.svg'),
  ),
  PrayerName.asr: PrayerData(
    prayerName: S.current.asr,
    prayerIcon: AssetsDir.iconsDir('icon_sun_descent.svg'),
  ),
  PrayerName.maghrib: PrayerData(
    prayerName: S.current.maghrib,
    prayerIcon: AssetsDir.iconsDir('icon_sunset.svg'),
  ),
  PrayerName.isha: PrayerData(
    prayerName: S.current.isha,
    prayerIcon: AssetsDir.iconsDir('icon_night.svg'),
  ),
};
