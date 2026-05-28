import 'package:hive/hive.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../domain/entities/hadith_bookmark.dart';

class HadithBookmarkLocalDataSource {
  HadithBookmarkLocalDataSource({required this.box});
  final Box<List> box;

  static const _key = 'all';

  Set<HadithBookmark> getAll() {
    final raw = box.get(_key);
    if (raw == null) return <HadithBookmark>{};
    final result = <HadithBookmark>{};
    for (final entry in raw) {
      if (entry is! String) continue;
      final parsed = HadithBookmark.tryParse(entry);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  /// Toggles the bookmark. Returns `true` if the bookmark is now present.
  Future<bool> toggle(HadithBookmark bookmark) async {
    try {
      final current =
          (box.get(_key) ?? <String>[]).cast<String>().toList(growable: true);
      final key = bookmark.storageKey;
      final wasPresent = current.remove(key);
      if (!wasPresent) current.add(key);
      await box.put(_key, current);
      return !wasPresent;
    } catch (e) {
      throw CacheException('hadith bookmark toggle failed: $e');
    }
  }
}
