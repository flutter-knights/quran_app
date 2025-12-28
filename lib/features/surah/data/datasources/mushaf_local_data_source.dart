import 'package:quran/quran.dart' as quran;
import '../models/mushaf_page_model.dart';

class MushafLocalDataSource {
  MushafPageModel getPage(int pageNumber) {
    final pageData = quran.getPageData(pageNumber);

    final List<String> ayahs = [];
    final List<int> surahHeadersIndexes = [];
    final List<String> surahNames = [];
    final List<bool> surahHasBasmala = [];

    for (var block in pageData) {
      int surah = block["surah"];
      int start = block["start"];
      int end = block["end"];

      // Surah header detection
      if (start == 1) {
        surahNames.add(quran.getQcfSurahName(surah));
        bool hasBasmala = surah != 9 && pageNumber != 1;
        surahHasBasmala.add(hasBasmala);

        // Add marker to insert header before this block
        surahHeadersIndexes.add(ayahs.length);
      }

      // Fill ayahs
      for (int ayah = start; ayah <= end; ayah++) {
        String verse = quran.getVerseQCF(surah, ayah);
        verse = preprocessVerse(verse, ayah, start);
        ayahs.add(verse);
      }
    }

    return MushafPageModel(
      pageNumber: pageNumber,
      ayahs: ayahs,
      surahNames: surahNames,
      surahHeadersIndexes: surahHeadersIndexes,
      showBasmalaList: surahHasBasmala,
    );
  }

  String preprocessVerse(String verse, int currentAyah, int startAyah) {
    // Remove all spaces
    String processed = verse.replaceAll(' ', '');

    if (currentAyah == startAyah && processed.isNotEmpty) {
      processed = '${processed.substring(0, 1)}\uFB50${processed.substring(1)}';
    }

    return processed;
  }
}
