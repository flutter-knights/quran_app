import 'package:dio/dio.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_page_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class AhadithRemoteDataSource {
  final Dio dio;
  final hadithApiKey =
      '\$2y\$10\$Vfjv5y14E1j5pqPcyvvGYm9UXBIFXvQ5xQKgCI7hVcVBRSQ6WZ1C';
  AhadithRemoteDataSource({required this.dio});

  Future<HadithPage> getAhadithPage(int pageNumber, String bookSlug) async {
    Response ahadithResponse = await dio.get(
      'https://hadithapi.com/api/hadiths/?apiKey=$hadithApiKey',
      queryParameters: {'pagination': 50, 'page': pageNumber, 'book': bookSlug},
    );

    HadithPage hadithPage = HadithPageModel.fromJson(ahadithResponse.data);
    return hadithPage;
  }
}
 