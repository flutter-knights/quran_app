import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

abstract class AhadithSearchRepository {
  void initializeArabicBookSearch(String bookSlug);
  Future<List<Hadith>> searchHadiths(String query);
  void dispose();
}
