import 'package:hive_flutter/adapters.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/home/data/models/location_hive_model.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';

Future<void> initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(PrayerTimesHiveModelAdapter());
  await Hive.openBox<PrayerTimesHiveModel>('prayerTimesCache');

  await Hive.openBox<String>('ayahAudioCache');
  Hive.registerAdapter(LocationHiveModelAdapter());
  await Hive.openBox<LocationHiveModel>('userLocationCache');
  Hive.registerAdapter(HadithHiveModelAdapter());
  await Hive.openBox<HadithHiveModel>('ahadithCache');

  await Hive.openBox<List>('ayah_bookmarks');
}
