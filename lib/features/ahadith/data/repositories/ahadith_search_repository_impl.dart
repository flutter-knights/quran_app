import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';

class AhadithSearchRepositoryImpl extends AhadithSearchRepository {
  @override
  void initializeArabicBookSearch(String bookSlug) {
    // TODO: implement initializeBookSearch
  }

  @override
  Future<List<Hadith>> searchHadiths(String query) {
    // TODO: implement searchHadiths
    throw UnimplementedError();
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }
}
