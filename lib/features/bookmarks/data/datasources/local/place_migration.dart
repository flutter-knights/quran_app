import 'package:hive_ce/hive.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../domain/entities/place.dart';
import '../../models/place_record_model.dart';

class PlaceMigration {
  PlaceMigration({
    required this.places,
    required this.meta,
    required this.ayahBookmarks,
    required this.pageBookmarks,
    required this.firstAyahOfPage,
    required this.pageOf,
    this.now = DateTime.now,
  });

  final Box<PlaceRecordModel> places;
  final Box<bool> meta;
  final Box<List> ayahBookmarks;
  final Box<List> pageBookmarks;
  final Future<AyahIdentifier?> Function(int page) firstAyahOfPage;
  final int Function(AyahIdentifier ayah) pageOf;
  final DateTime Function() now;

  static const flag = 'migratedV1';
  static const _key = 'all';

  static int? parsePage(Object? e) => e is int ? e : int.tryParse('$e');

  static AyahIdentifier? parseAyahKey(Object? e) {
    if (e is! String) return null;
    final parts = e.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null || ayah <= 0) return null;
    return AyahIdentifier(surah: surah, ayah: ayah);
  }

  static List<Place> plan({
    required List<Object?> ayahKeys,
    required List<Object?> pages,
    required Map<int, AyahIdentifier> firstAyahs,
    required int Function(AyahIdentifier ayah) pageOf,
    required DateTime now,
  }) {
    final entries = <AyahIdentifier, int>{};
    for (final key in ayahKeys) {
      final ayah = parseAyahKey(key);
      if (ayah == null || entries.containsKey(ayah)) continue;
      final page = _pageOrNull(pageOf, ayah);
      if (page != null) entries[ayah] = page;
    }
    for (final entry in pages) {
      final page = parsePage(entry);
      if (page == null) continue;
      final ayah = firstAyahs[page];
      if (ayah != null) entries.putIfAbsent(ayah, () => page);
    }
    return [
      for (final (i, e) in entries.entries.indexed)
        _place(e.key, e.value, now.subtract(Duration(microseconds: i))),
    ];
  }

  static int? _pageOrNull(
    int Function(AyahIdentifier) pageOf,
    AyahIdentifier a,
  ) {
    try {
      return pageOf(a);
    } catch (_) {
      return null;
    }
  }

  static Place _place(AyahIdentifier ayah, int page, DateTime at) => Place(
    id: at.microsecondsSinceEpoch.toString(),
    ayah: ayah,
    page: page,
    createdAt: at,
    updatedAt: at,
    migrated: true,
  );

  Future<int> run() async {
    if (meta.get(flag) == true) return 0;
    final ayahKeys = [...?ayahBookmarks.get(_key)];
    final pages = [...?pageBookmarks.get(_key)];
    final firstAyahs = <int, AyahIdentifier>{};
    for (final page in pages.map(parsePage).nonNulls.toSet()) {
      final ayah = await firstAyahOfPage(page);
      if (ayah != null) firstAyahs[page] = ayah;
    }
    final readerSaved = {
      for (final r in places.values)
        if (r.slot == null && !r.migrated)
          AyahIdentifier(surah: r.surah, ayah: r.ayah),
    };
    final planned = plan(
      ayahKeys: ayahKeys,
      pages: pages,
      firstAyahs: firstAyahs,
      pageOf: pageOf,
      now: now(),
    ).where((p) => !readerSaved.contains(p.ayah)).toList();
    await places.deleteAll([
      for (final r in places.values)
        if (r.migrated) r.key,
    ]);
    await places.putAll({
      for (final p in planned) p.id: PlaceRecordModel.fromEntity(p),
    });
    final written = places.values.where((r) => r.migrated).length;
    if (written != planned.length ||
        !planned.every((p) => places.containsKey(p.id))) {
      throw CacheException('place migration count mismatch');
    }
    await meta.put(flag, true);
    return planned.length;
  }
}
