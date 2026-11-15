import 'package:quran_app/core/constants/prayer_name.dart';

const _arabic = {
  PrayerName.fajr: 'الفجر',
  PrayerName.dhuhr: 'الظهر',
  PrayerName.asr: 'العصر',
  PrayerName.maghrib: 'المغرب',
  PrayerName.isha: 'العشاء',
};

const _english = {
  PrayerName.fajr: 'Fajr',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

String prayerNameLabel(
  PrayerName prayer, {
  required bool arabic,
  bool friday = false,
}) {
  if (friday && prayer == PrayerName.dhuhr) {
    return arabic ? 'الجمعة' : "Jumu'ah";
  }
  return (arabic ? _arabic : _english)[prayer] ?? prayer.name;
}
