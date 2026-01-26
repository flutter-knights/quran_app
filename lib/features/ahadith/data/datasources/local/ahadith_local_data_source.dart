import 'package:hive/hive.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/core/helper%20functions/search_helpers.dart';
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
      ahadithList: SearchHelpers.sortHadiths(ahadithList),
      currentPage: pageNumber,
      lastPage: isLastPage,
    );
  }

  List<Hadith> getSearchedHadiths(String query, String bookSlug) {
    final bool isArabicQuery = SearchHelpers.isArabic(query);
    final String searchQuery = isArabicQuery
        ? SearchHelpers.cleanArabicQuery(query)
        : query.toLowerCase();
    final String keyPrefix = "${bookSlug}_";

    final allKeys = hadithBox.keys.map((e) => e.toString()).toList();
    final relevantKeys = allKeys
        .where((key) => key.startsWith(keyPrefix))
        .toList();

    if (relevantKeys.isEmpty) return [];

    final List<Hadith> results = [];

    for (final key in relevantKeys) {
      final model = hadithBox.get(key);
      if (model == null) continue;

      bool matches = false;
      if (isArabicQuery) {
        matches = SearchHelpers.cleanArabicQuery(
          model.arabicHadith,
        ).contains(searchQuery);
      } else {
        matches = model.englishHadith.toLowerCase().contains(searchQuery);
      }

      if (matches) {
        results.add(model.toEntity());
      }
      if (results.length >= kPageLimit) break;
    }

    return SearchHelpers.sortHadiths(results);
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
