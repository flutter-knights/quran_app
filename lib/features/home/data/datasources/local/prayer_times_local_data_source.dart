import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimesLocalDataSource {
  Box<PrayerTimesHiveModel> prayerTimesBox;
  PrayerTimesLocalDataSource({required this.prayerTimesBox});

  PrayerTimes cacheToHive(List<PrayerTimes> prayerTimes) {
    for (PrayerTimes prayerTime in prayerTimes) {
      prayerTimesBox.put(prayerTime.date.day, prayerTime.toHive());
    }
    return getFromHive()!;
  }

  PrayerTimes? getFromHive() {
    final now = DateTime.now();

    final todaysDate = DateFormat('dd-MM-yyyy').format(now);

    final todaysPrayerTimes = prayerTimesBox.get(todaysDate);
    if (prayerTimesBox.isEmpty || todaysPrayerTimes == null) return null;
    return todaysPrayerTimes.toEntity();
  }

  void clearCache() {
    prayerTimesBox.clear();
  }
}
