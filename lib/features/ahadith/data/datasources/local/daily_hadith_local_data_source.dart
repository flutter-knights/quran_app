import 'package:hive/hive.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';

/// Caches the resolved "Hadith of the Day", keyed by its UTC date string, so it
/// is fetched at most once per day and remains available offline afterwards.
class DailyHadithLocalDataSource {
  DailyHadithLocalDataSource({required this.box});
  final Box<HadithHiveModel> box;

  HadithHiveModel? get(String dateKey) => box.get(dateKey);

  Future<void> put(String dateKey, HadithHiveModel model) =>
      box.put(dateKey, model);
}
