import 'package:hive_flutter/adapters.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';

Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox<PrayerTimesHiveModel>('prayerTimesCache');
}
