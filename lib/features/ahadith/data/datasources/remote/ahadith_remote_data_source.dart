import 'package:dio/dio.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/core/helper%20functions/search_helpers.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_page_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class AhadithRemoteDataSource {
  final Dio dio;
  final hadithApiKey =
      r'$2y$10$Vfjv5y14E1j5pqPcyvvGYm9UXBIFXvQ5xQKgCI7hVcVBRSQ6WZ1C';
  AhadithRemoteDataSource({required this.dio});

  Future<HadithPage> getAhadithPage(int pageNumber, String bookSlug) async {
    Response ahadithResponse = await dio.get(
      'https://hadithapi.com/api/hadiths/?apiKey=$hadithApiKey',
      queryParameters: {
        'paginate': kPageLimit,
        'page': pageNumber,
        'book': bookSlug,
      },
    );

    HadithPage hadithPage = HadithPageModel.fromJson(ahadithResponse.data);
    return hadithPage;
  }

  Future<HadithPage> getSearchedHadiths(String query, String bookSlug) async {
    Response ahadithResponse = await dio.get(
      'https://hadithapi.com/api/hadiths/?apiKey=$hadithApiKey',
      queryParameters: {'paginate': kPageLimit, 'book': bookSlug},
    );

    HadithPage hadithPage = HadithPageModel.fromJson(ahadithResponse.data);
    return hadithPage;
  }
}
