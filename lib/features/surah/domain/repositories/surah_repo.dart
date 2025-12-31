import '../entities/surah_entity.dart';

abstract class SurahRepository {
  Future<List<SurahEntity>> getAllSurahs();
}
