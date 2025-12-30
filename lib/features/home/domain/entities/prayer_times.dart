import 'package:quran_app/core/constants/prayers_list_constants.dart';

class PrayerTimes {
  final String key;
  final Map<PrayerName, String> timings;
  final Date date;

  const PrayerTimes({
    required this.key,
    required this.timings,
    required this.date,
  });
}

class Date {
  final String month;
  final String weekDay;
  final String year;
  final String day;
  final String enMonth;
  final String enWeekDay;
  final String gregorianDate;

  Date({
    required this.month,
    required this.weekDay,
    required this.day,
    required this.year,
    required this.enMonth,
    required this.enWeekDay,
    required this.gregorianDate,
  });
}
