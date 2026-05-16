import 'package:hive/hive.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';

class BookmarkLocalDataSource {
  BookmarkLocalDataSource({required this.box});
  final Box<List> box;

  static const _key = 'all';

  Set<AyahIdentifier> getAll() {
    final raw = box.get(_key);
    if (raw == null) return <AyahIdentifier>{};
    final result = <AyahIdentifier>{};
    for (final entry in raw) {
      final parsed = _parse(entry);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  Future<bool> toggle({required int surah, required int ayah}) async {
    try {
      final current =
          (box.get(_key) ?? <String>[]).cast<String>().toList(growable: true);
      final key = '$surah:$ayah';
      final wasPresent = current.remove(key);
      if (!wasPresent) current.add(key);
      await box.put(_key, current);
      return !wasPresent;
    } catch (e) {
      throw CacheException('bookmark toggle failed: $e');
    }
  }

  AyahIdentifier? _parse(dynamic raw) {
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return null;
    return AyahIdentifier(surah: surah, ayah: ayah);
  }
}
