import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimesLocalDataSource {
  Box<PrayerTimesHiveModel> prayerTimesBox;
  PrayerTimesLocalDataSource({required this.prayerTimesBox});

  Future<void> cache(List<PrayerTimes> prayerTimes) async {
    final Map<String, PrayerTimesHiveModel> entries = {
      for (var p in prayerTimes) p.key: p.toHive(),
    };
    await prayerTimesBox.putAll(entries);
    await clearOldCache();
  }

  PrayerTimes? getCached({DateTime? date}) {
    final String todaysDate = formatKey(date: date);

    final todaysPrayerTimes = prayerTimesBox.get(todaysDate);
    if (prayerTimesBox.isEmpty || todaysPrayerTimes == null) return null;
    return todaysPrayerTimes.toEntity();
  }

  void clearCache() {
    prayerTimesBox.clear();
  }

  Future<void> clearOldCache() async {
    final prayerTimesKeys = prayerTimesBox.keys.toList();
    final keysLength = prayerTimesKeys.length;
    if (keysLength < 40) return;
    final keysToRemove = prayerTimesKeys.sublist(0, keysLength - 40);

    await prayerTimesBox.deleteAll(keysToRemove);
  }
}

String formatKey({DateTime? date}) {
  final now = date ?? DateTime.now();
  final String todaysDate = DateFormat('dd-MM-yyyy', 'en').format(now);
  return todaysDate;
}
