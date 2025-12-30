import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

class HadithPage {
  final List<Hadith> ahadithList;
  final int currentPage;
  final bool lastPage;

  HadithPage({
    required this.ahadithList,
    required this.currentPage,
    required this.lastPage,
  });
}
