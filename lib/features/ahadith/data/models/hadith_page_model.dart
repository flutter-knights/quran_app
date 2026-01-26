
import 'package:quran_app/core/helper%20functions/search_helpers.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class HadithPageModel extends HadithPage {
  HadithPageModel({
    required super.ahadithList,
    required super.currentPage,
    required super.lastPage,
  });

  factory HadithPageModel.fromJson(Map<String, dynamic> json) {
    final hadithsData = json['hadiths'];

    return HadithPageModel(
      currentPage: hadithsData['current_page'],
      lastPage: hadithsData['next_page_url'] == null,
      ahadithList: (hadithsData['data'] as List)
          .map(
            (e) => HadithModel.fromJson(e).copyWith(
              arabicNormalized: SearchHelpers.cleanArabicQuery(
                HadithModel.fromJson(e).arabicHadith,
              ),
            ),
          ) // Pass the map here
          .toList(),
    );
  }
}
