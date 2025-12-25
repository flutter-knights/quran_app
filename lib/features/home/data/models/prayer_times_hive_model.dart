import 'package:hive/hive.dart'; // Change to standard hive for annotations
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

part 'prayer_times_hive_model.g.dart'; 

@HiveType(typeId: 0) 
class PrayerTimesHiveModel extends HiveObject {
  @HiveField(0)
  final String fajr;

  @HiveField(1)
  final String sunrise;

  @HiveField(2)
  final String dhuhr;

  @HiveField(3)
  final String asr;

  @HiveField(4)
  final String maghrib;

  @HiveField(5)
  final String isha;

  @HiveField(6)
  final String hijriMonth;

  @HiveField(7)
  final String hijriWeekDay;

  @HiveField(8)
  final String hijriYear;

  @HiveField(9)
  final String hijriDay;

  @HiveField(10)
  @override
  final String key;

  @HiveField(11) 
  final String enHijriMonth;

  @HiveField(12) 
  final String enHijriWeekDay;

  PrayerTimesHiveModel({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.hijriMonth,
    required this.hijriWeekDay,
    required this.hijriYear,
    required this.hijriDay,
    required this.key,
    required this.enHijriMonth,
    required this.enHijriWeekDay,
  });
}

extension PrayerTimesEntityMapper on PrayerTimes {
  PrayerTimesHiveModel toHive() {
    return PrayerTimesHiveModel(
      key: key,
      fajr: timings[PrayerName.fajr]!,
      sunrise: timings[PrayerName.sunrise]!,
      dhuhr: timings[PrayerName.dhuhr]!,
      asr: timings[PrayerName.asr]!,
      maghrib: timings[PrayerName.maghrib]!,
      isha: timings[PrayerName.isha]!,
      hijriMonth: date.month,
      hijriWeekDay: date.weekDay,
      hijriYear: date.year,
      hijriDay: date.day,
      enHijriMonth: date.enMonth,
      enHijriWeekDay: date.enWeekDay,
    );
  }
}

extension PrayerTimesHiveMapper on PrayerTimesHiveModel {
  PrayerTimes toEntity() {
    return PrayerTimes(
      key: key,
      timings: {
        PrayerName.fajr: fajr,
        PrayerName.sunrise: sunrise,
        PrayerName.dhuhr: dhuhr,
        PrayerName.asr: asr,
        PrayerName.maghrib: maghrib,
        PrayerName.isha: isha,
      },
      date: Date(
        month: hijriMonth,
        weekDay: hijriWeekDay,
        year: hijriYear,
        day: hijriDay,
        enMonth: enHijriMonth,
        enWeekDay: enHijriWeekDay,
      ),
    );
  }
}
