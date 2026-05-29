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

    for (final number in ahadithNumbers) {
      bool foundInHive = false;
      final int num = int.tryParse(number.split(',').first) ?? 0;
      final int estimatedPage = (num / kPageLimit).ceil();

      for (int p = estimatedPage - 1; p <= estimatedPage + 1; p++) {
        if (p < 1) continue;

        final String normalKey = "${bookSlug}_${p}_$number";
        final String lastKey = "${bookSlug}_${p}_${number}_last";

        final model = hadithBox.get(normalKey) ?? hadithBox.get(lastKey);

        if (model != null) {
          results.add(model.toEntity());
          foundInHive = true;
          break;
        }
      }
      if (!foundInHive) {
        missing.add(number);
      }
    }

    return (found: AhadithHelpers.sortHadiths(results), missing: missing);
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
