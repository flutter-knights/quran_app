import 'package:hive/hive.dart';

import '../../../../../core/errors/exceptions.dart';

/// Page-level bookmarks. Stored as a `List<int>` of page numbers under one key,
/// mirroring the ayah `BookmarkLocalDataSource` shape.
class PageBookmarkLocalDataSource {
  PageBookmarkLocalDataSource({required this.box});
  final Box<List> box;

  static const _key = 'all';

  Set<int> getAll() {
    final raw = box.get(_key);
    if (raw == null) return <int>{};
    final result = <int>{};
    for (final entry in raw) {
      if (entry is int) {
        result.add(entry);
      } else {
        final parsed = int.tryParse('$entry');
        if (parsed != null) result.add(parsed);
      }
    }
    return result;
  }

  Future<bool> toggle(int page) async {
    try {
      final current = (box.get(_key) ?? <int>[])
          .map((e) => e is int ? e : int.parse('$e'))
          .toList(growable: true);
      final wasPresent = current.remove(page);
      if (!wasPresent) current.add(page);
      await box.put(_key, current);
      return !wasPresent;
    } catch (e) {
      throw CacheException('page bookmark toggle failed: $e');
    }
  }
}
