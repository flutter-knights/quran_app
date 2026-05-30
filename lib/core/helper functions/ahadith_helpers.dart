import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

class AhadithHelpers {
  static final RegExp _diacriticsRegex = RegExp(
    r'[\u064B-\u0652\u06D6-\u06ED\u0640]',
  );
  static String cleanArabicQuery(String input) {
    if (input.isEmpty) return input;
    String result = input.replaceAll(_diacriticsRegex, '');
    result = result.replaceAll(RegExp(r'[أإآ]'), 'ا');
    result = result.replaceAll('ة', 'ه');
    result = result.replaceAll('ى', 'ي');

    return result.trim();
  }

  static List<Hadith> sortHadiths(List<Hadith> list) {
    list.sort((a, b) {
      final String partA = a.hadithNumber.split(',').first.trim();
      final String partB = b.hadithNumber.split(',').first.trim();

      final int? numA = int.tryParse(partA);
      final int? numB = int.tryParse(partB);

      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }
      return a.hadithNumber.compareTo(b.hadithNumber);
    });

    return list;
  }

  static bool isArabic(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }
}
