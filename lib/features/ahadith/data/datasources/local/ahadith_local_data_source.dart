import 'package:hive/hive.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class AhadithLocalDataSource {
  final Box<HadithHiveModel> hadithBox;
  final Map<String, dynamic> chapters;
  AhadithLocalDataSource({required this.hadithBox, required this.chapters});

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
      ahadithList: ahadithList,
      currentPage: pageNumber,
      lastPage: isLastPage,
    );
  }

  void cachePage(HadithPage hadithPage, int pageNumber, String bookSlug) {
    final Map<String, HadithHiveModel> entries = {};

    for (var hadith in hadithPage.ahadithList) {
      String compositeKey = "${bookSlug}_${pageNumber}_${hadith.id}";
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
}
