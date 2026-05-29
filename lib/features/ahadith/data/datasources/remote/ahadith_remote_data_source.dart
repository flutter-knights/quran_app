import 'package:dio/dio.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_model.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_page_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
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

  /// A book page filtered server-side by [status] (API value, e.g. `Da`eef`)
  /// and/or [chapterNumber], so the client doesn't page through the whole book
  /// hunting for matches.
  Future<HadithPage> getFilteredAhadithPage(
    int pageNumber,
    String bookSlug, {
    String? status,
    int? chapterNumber,
  }) async {
    Response ahadithResponse = await dio.get(
      'https://hadithapi.com/api/hadiths/?apiKey=$hadithApiKey',
      queryParameters: {
        'paginate': kPageLimit,
        'page': pageNumber,
        'book': bookSlug,
        if (status != null) 'status': status,
        if (chapterNumber != null) 'chapter': chapterNumber,
      },
    );

    return HadithPageModel.fromJson(ahadithResponse.data);
  }

  Future<List<Hadith>> getSearchedHadiths(String query, String bookSlug) async {
    final Response ahadithResponse;
    try {
      ahadithResponse = await dio.get(
        'https://hadithapi.com/api/hadiths/?apiKey=$hadithApiKey',
        queryParameters: {
          'paginate': kPageLimit,
          'book': bookSlug,
          'hadithEnglish': query,
        },
      );
    } on DioException catch (e) {
      // No matches comes back as 404 — that's an empty result, not an error.
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
    final List<dynamic>? dataList = ahadithResponse.data['hadiths']?['data'];

    if (dataList == null || dataList.isEmpty) return [];
    List<Hadith> ahadithList = dataList
        .map((e) => HadithModel.fromJson(e))
        .toList();
    return ahadithList;
  }

  Future<List<Hadith>> getAhadithByNumbers(
    List<String> ahadithNumbers,
    String bookSlug,
  ) async {
    final futures = ahadithNumbers.map((number) async {
      final firstNumber = number.split(',').first;
      try {
        final res = await dio.get(
          'https://hadithapi.com/api/hadiths/?apiKey=$hadithApiKey',
          queryParameters: {'book': bookSlug, 'hadithNumber': firstNumber},
        );
        final List<dynamic>? dataList = res.data['hadiths']?['data'];
        if (dataList == null || dataList.isEmpty) return null;
        return HadithModel.fromJson(dataList.first);
      } on DioException catch (e) {
        // A missing hadith number returns 404 — skip it, don't fail the batch.
        if (e.response?.statusCode == 404) return null;
        rethrow;
      }
    });

    final results = await Future.wait(futures);
    return results.whereType<Hadith>().toList();
  }
}
