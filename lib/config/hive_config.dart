import 'package:hive_flutter/adapters.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/home/data/models/location_hive_model.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';
import 'package:quran_app/features/surah/data/models/last_read_hive_model.dart';

Future<void> initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(PrayerTimesHiveModelAdapter());
  await Hive.openBox<PrayerTimesHiveModel>('prayerTimesCache');

  await Hive.openBox<String>('ayahAudioCache');
  Hive.registerAdapter(LocationHiveModelAdapter());
  await Hive.openBox<LocationHiveModel>('userLocationCache');
  Hive.registerAdapter(HadithHiveModelAdapter());
  await _openCacheBox<HadithHiveModel>('ahadithCache');
  await _openCacheBox<HadithHiveModel>('daily_hadith');

  await Hive.openBox<List>('ayah_bookmarks');
  await Hive.openBox<List>('hadith_bookmarks');
  Hive.registerAdapter(LastReadHiveModelAdapter());
  await Hive.openBox<LastReadHiveModel>('last_read');
  await Hive.openBox('prayerConfig');
}

/// Opens a box that only holds re-fetchable cached data. If the on-disk records
/// are incompatible with the current adapter schema (e.g. a field's type
/// changed under the same typeId, as `hadithNumber` did int -> String), the
/// stale box is discarded and reopened fresh rather than crashing on launch.
/// Never use this for boxes holding user data.
Future<Box<T>> _openCacheBox<T>(String name) async {
  try {
    return await Hive.openBox<T>(name);
  } catch (_) {
    await Hive.deleteBoxFromDisk(name);
    return await Hive.openBox<T>(name);
  }
}
