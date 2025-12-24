import 'package:hive_flutter/adapters.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

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
  });
}

extension PrayerTimesEntityMapper on PrayerTimes {
  PrayerTimesHiveModel toHive() {
    return PrayerTimesHiveModel(
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
    );
  }
}

extension PrayerTimesHiveMapper on PrayerTimesHiveModel {
  PrayerTimes toEntity() {
    return PrayerTimes(
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
      ),
    );
  }
}
