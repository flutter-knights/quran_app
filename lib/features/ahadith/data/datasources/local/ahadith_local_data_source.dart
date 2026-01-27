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

  List<Hadith> getAhadithByNumbers(
    List<String> ahadithNumbers,
    String bookSlug,
  ) {
    final List<Hadith> results = [];

    for (final number in ahadithNumbers) {
      final int num = int.tryParse(number) ?? 0;
      final int estimatedPage = (num / kPageLimit).ceil();

      for (int p = estimatedPage - 1; p <= estimatedPage + 1; p++) {
        if (p < 1) continue;

        final String normalKey = "${bookSlug}_${p}_$number";
        final String lastKey = "${bookSlug}_${p}_${number}_last";

        if (hadithBox.containsKey(normalKey)) {
          results.add(hadithBox.get(normalKey)!.toEntity());
          break;
        } else if (hadithBox.containsKey(lastKey)) {
          results.add(hadithBox.get(lastKey)!.toEntity());
          break;
        }
      }
    }
    return AhadithHelpers.sortHadiths(results);
  }

  List<Hadith> getSearchedHadiths(String query, String bookSlug) {
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

      final matches = model.englishHadith.toLowerCase().contains(query);

      if (matches) {
        results.add(model.toEntity());
      }
      if (results.length >= kPageLimit) break;
    }

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
