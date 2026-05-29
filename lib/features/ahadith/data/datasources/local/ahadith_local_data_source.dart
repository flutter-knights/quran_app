import 'package:hive/hive.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class AhadithLocalDataSource {
  final Box<HadithHiveModel> hadithBox;
  AhadithLocalDataSource({required this.hadithBox});

  HadithPage? getCachedPage(int pageNumber, String bookSlug) {
    final String keyPrefix = "${bookSlug}_${pageNumber}_";

    final allKeys = hadithBox.keys.map((e) => e.toString()).toList();
    final relevantKeys = allKeys
        .where((key) => key.startsWith(keyPrefix))
        .toList();

    if (relevantKeys.isEmpty) return null;

    final bool isLastPage = relevantKeys.any((key) => key.contains("_last"));

    final List<Hadith> ahadithList = relevantKeys
        .map((key) => hadithBox.get(key)!.toEntity())
        .toList();

    return HadithPage(
      ahadithList: AhadithHelpers.sortHadiths(ahadithList),
      currentPage: pageNumber,
      lastPage: isLastPage,
    );
  }

  ({List<Hadith> found, List<String> missing}) getAhadithByNumbers(
    List<String> ahadithNumbers,
    String bookSlug,
  ) {
    final List<Hadith> results = [];
    final List<String> missing = [];

    // Lazily built only if the page-estimate fast path misses, so the common
    // case never pays for a full key scan.
    Map<String, HadithHiveModel>? scanIndex;

    for (final number in ahadithNumbers) {
      final int num = int.tryParse(number.split(',').first) ?? 0;
      final int estimatedPage = (num / kPageLimit).ceil();

      HadithHiveModel? model;

      // Fast path: hadith numbers are roughly sequential, so the cached page
      // is almost always estimatedPage ± 1.
      for (int p = estimatedPage - 1; p <= estimatedPage + 1; p++) {
        if (p < 1) continue;
        final String normalKey = "${bookSlug}_${p}_$number";
        final String lastKey = "${bookSlug}_${p}_${number}_last";
        model = hadithBox.get(normalKey) ?? hadithBox.get(lastKey);
        if (model != null) break;
      }

      // Fallback: the estimate can miss when numbering isn't densely
      // sequential (gaps, ranges). Scan the book's keys before giving up so a
      // cached hadith is never wrongly reported missing.
      if (model == null) {
        scanIndex ??= _buildBookIndex(bookSlug);
        model = scanIndex[number];
      }

      if (model != null) {
        results.add(model.toEntity());
      } else {
        missing.add(number);
      }
    }

    return (found: AhadithHelpers.sortHadiths(results), missing: missing);
  }

  /// Maps every cached hadith number in [bookSlug] to its model, regardless of
  /// which page it landed on. Built once per call only when needed.
  Map<String, HadithHiveModel> _buildBookIndex(String bookSlug) {
    final String prefix = "${bookSlug}_";
    final Map<String, HadithHiveModel> index = {};
    for (final key in hadithBox.keys) {
      final keyStr = key.toString();
      if (!keyStr.startsWith(prefix)) continue;
      final model = hadithBox.get(key);
      if (model != null) index[model.hadithNumber] = model;
    }
    return index;
  }

  List<Hadith> getSearchedHadiths(String query, String bookSlug) {
    final String keyPrefix = "${bookSlug}_";
    final String lowercaseQuery = query.toLowerCase();

    final allKeys = hadithBox.keys.cast<String>();

    final relevantKeys = allKeys.where((key) => key.startsWith(keyPrefix));

    if (relevantKeys.isEmpty) return [];

    final List<Hadith> results = relevantKeys
        .map((key) => hadithBox.get(key))
        .where((model) => model != null)
        .where(
          (model) =>
              model!.englishHadith.toLowerCase().contains(lowercaseQuery),
        )
        .take(kPageLimit)
        .map((model) => model!.toEntity())
        .toList();

    return AhadithHelpers.sortHadiths(results);
  }

  void cachePage(HadithPage hadithPage, int pageNumber, String bookSlug) {
    final Map<String, HadithHiveModel> entries = {};

    for (var hadith in hadithPage.ahadithList) {
      String compositeKey = "${bookSlug}_${pageNumber}_${hadith.hadithNumber}";
      if (hadithPage.lastPage) {
        compositeKey += "_last";
      }

      entries[compositeKey] = HadithHiveModel.fromEntity(
        hadith,
        pageNumber,
        bookSlug,
      );
    }

    hadithBox.putAll(entries);
  }

  Future<void> clearBookCache(String bookSlug) async {
    final String prefix = "${bookSlug}_";

    final keysToDelete = hadithBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .toList();

    if (keysToDelete.isNotEmpty) {
      await hadithBox.deleteAll(keysToDelete);
    }
  }

  Future<void> clearAllCache() async {
    await hadithBox.clear();
  }
}
