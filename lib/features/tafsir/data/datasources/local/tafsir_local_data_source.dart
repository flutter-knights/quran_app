import 'package:hive_ce/hive.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../domain/entities/tafsir.dart';

class TafsirLocalDataSource {
  TafsirLocalDataSource({required this.box});

  final Box<String> box;

  static String keyOf(int surah, int ayah) => 'muyassar:$surah:$ayah';

  String? get(int surah, int ayah) {
    try {
      return box.get(keyOf(surah, ayah));
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  Future<void> putAll(Iterable<Tafsir> items) async {
    try {
      await box.putAll({for (final t in items) keyOf(t.surah, t.ayah): t.text});
    } catch (e) {
      throw CacheException(e.toString());
    }
  }
}
