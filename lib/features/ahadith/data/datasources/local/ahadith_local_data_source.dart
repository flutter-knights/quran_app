import 'package:hive/hive.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class AhadithLocalDataSource {
  final Box<HadithHiveModel> hadithBox;

  AhadithLocalDataSource({required this.hadithBox});

  HadithPage? getCachedPage(int pageNumber, String bookSlug) {
    final String keyPrefix = "${bookSlug}_${pageNumber}_";
    final String nextKeyPrefix = "${bookSlug}_${pageNumber + 1}_";

    final relevantKeys = hadithBox.keys
        .where((key) => key.toString().startsWith(keyPrefix))
        .toList();

    if (relevantKeys.isEmpty) return null;

    final bool isLastPage = hadithBox.keys
        .where((key) => key.toString().startsWith(nextKeyPrefix))
        .isEmpty;

    final List<Hadith> ahadithList = relevantKeys
        .map((key) => hadithBox.get(key)!.toEntity())
        .toList();

    return HadithPage(
      ahadithList: ahadithList,
      currentPage: pageNumber,
      lastPage: isLastPage,
    );
  }

  void cachePage(HadithPage hadithPage, int pageNumber, String bookSlug) {
    final Map<dynamic, HadithHiveModel> entries = {};

    for (var hadith in hadithPage.ahadithList) {
      final String compositeKey = "${bookSlug}_${pageNumber}_${hadith.id}";

      entries[compositeKey] = HadithHiveModel.fromEntity(
        hadith,
        pageNumber,
        bookSlug,
      );
    }
    hadithBox.putAll(entries);
  }

  void clearCache() {
    hadithBox.clear();
  }
}
