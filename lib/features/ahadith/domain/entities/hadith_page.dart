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

  HadithPage copyWith({
    List<Hadith>? ahadithList,
    int? currentPage,
    bool? lastPage,
  }) {
    return HadithPage(
      ahadithList: ahadithList ?? this.ahadithList,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
    );
  }
}
