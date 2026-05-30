import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

/// One entry in the per-book Arabic search index: normalized text plus the
/// chapter id and grade needed to filter matches before the result cap.
class ArabicIndexEntry {
  final String text;
  final int? chapterId;
  final HadithStatus? status;
  const ArabicIndexEntry({required this.text, this.chapterId, this.status});
}

/// Parses an index value, tolerating both the new object form
/// `{"t":..,"c":..,"s":..}` and the legacy bare-string form (text only).
ArabicIndexEntry parseIndexValue(dynamic value) {
  if (value is Map) {
    return ArabicIndexEntry(
      text: (value['t'] ?? '').toString(),
      chapterId: value['c'] is int ? value['c'] as int : null,
      status: _statusFromName(value['s']?.toString()),
    );
  }
  return ArabicIndexEntry(text: value.toString());
}

HadithStatus? _statusFromName(String? name) {
  if (name == null) return null;
  for (final s in HadithStatus.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// Pure search over the parsed index: text-contains + optional chapter/grade,
/// filtered BEFORE [limit] so a chapter/grade is never truncated away.
List<String> searchIndexEntries(
  Map<String, ArabicIndexEntry> index,
  String normalizedQuery, {
  HadithStatus? status,
  int? chapterId,
  required int limit,
}) {
  return index.entries
      .where((e) => e.value.text.contains(normalizedQuery))
      .where((e) => status == null || e.value.status == status)
      .where((e) => chapterId == null || e.value.chapterId == chapterId)
      .map((e) => e.key)
      .take(limit)
      .toList();
}

class AhadithArabicSearchLocalDataSource {
  Map<String, ArabicIndexEntry>? _currentMapInMemory;
  Future<void>? _initFuture;

  Future<void> initBook(String bookSlug) {
    _initFuture = _loadIndex(bookSlug);
    return _initFuture!;
  }

  Future<void> _loadIndex(String bookSlug) async {
    final data = await rootBundle.load('assets/json/ahadith_indices.zip');
    final bytes = data.buffer.asUint8List();
    _currentMapInMemory =
        await compute(_parseZipInBackground, _ZipArgs(bytes, bookSlug));
  }

  Future<List<String>> getSearchedHadithsNumbers({
    required String query,
    HadithStatus? status,
    int? chapterId,
  }) async {
    try {
      await _initFuture;
    } catch (_) {
      return [];
    }
    final index = _currentMapInMemory;
    if (index == null) return [];
    final normalized = AhadithHelpers.cleanArabicQuery(query);
    return searchIndexEntries(
      index,
      normalized,
      status: status,
      chapterId: chapterId,
      limit: kArabicSearchResultLimit,
    );
  }

  void clearCurrentBook() {
    _currentMapInMemory = null;
    _initFuture = null;
  }
}

Map<String, ArabicIndexEntry> _parseZipInBackground(_ZipArgs args) {
  final archive = ZipDecoder().decodeBytes(args.bytes);
  final file = archive.findFile('${args.slug}.json');
  if (file == null) return {};

  final content = utf8.decode(file.content as List<int>);
  final Map<String, dynamic> decoded = jsonDecode(content);
  return decoded.map((key, value) => MapEntry(key, parseIndexValue(value)));
}

class _ZipArgs {
  final Uint8List bytes;
  final String slug;
  _ZipArgs(this.bytes, this.slug);
}
