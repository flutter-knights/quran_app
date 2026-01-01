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
    final now = DateTime.now();
    final threshold = DateTime(now.year, now.month, now.day - 1);

    final keysToRemove = <dynamic>[];

    for (var key in prayerTimesBox.keys) {
      DateTime? keyDate;
      if (key is DateTime) {
        keyDate = key;
      } else if (key is String) {
        keyDate = DateTime.tryParse(key);
      }

      if (keyDate != null && keyDate.isBefore(threshold)) {
        keysToRemove.add(key);
      }
    }

    if (keysToRemove.isNotEmpty) {
      await prayerTimesBox.deleteAll(keysToRemove);
    }
  }
}

String formatKey({DateTime? date}) {
  final now = date ?? DateTime.now();
  final String todaysDate = DateFormat('dd-MM-yyyy', 'en').format(now);
  return todaysDate;
}
