import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';

class AhadithArabicSearchLocalDataSource {
  Map<String, String>? _currentMapInMemory;
  Future<void>? _initFuture;

  Future<void> initBook(String bookSlug) {
    _initFuture = _loadIndex(bookSlug);
    return _initFuture!;
  }

  Future<void> _loadIndex(String bookSlug) async {
    final data = await rootBundle.load('assets/json/ahadith_indices.zip');
    final bytes = data.buffer.asUint8List();
    _currentMapInMemory = await compute(
      _parseZipInBackground,
      _ZipArgs(bytes, bookSlug),
    );
  }

  Future<List<String>> getSearchedHadithsNumbers({
    required String query,
  }) async {
    // Wait for the index to finish loading instead of reporting a false
    // "no results" when a query arrives mid-decode. A load/decode failure
    // degrades to empty results rather than crashing the search flow.
    try {
      await _initFuture;
    } catch (_) {
      return [];
    }
    if (_currentMapInMemory == null) return [];
    query = AhadithHelpers.cleanArabicQuery(query);
    final List<String> result = _currentMapInMemory!.entries
        .where((e) => e.value.contains(query))
        .map((e) => e.key)
        .take(kArabicSearchResultLimit)
        .toList();
    return result;
  }

  void clearCurrentBook() {
    _currentMapInMemory = null;
    _initFuture = null;
  }
}

Map<String, String> _parseZipInBackground(_ZipArgs args) {
  final archive = ZipDecoder().decodeBytes(args.bytes);
  final file = archive.findFile('${args.slug}.json');

  if (file == null) return {};

  final content = utf8.decode(file.content as List<int>);
  final Map<String, dynamic> decoded = jsonDecode(content);

  return decoded.map((key, value) => MapEntry(key, value.toString()));
}

class _ZipArgs {
  final Uint8List bytes;
  final String slug;
  _ZipArgs(this.bytes, this.slug);
}
