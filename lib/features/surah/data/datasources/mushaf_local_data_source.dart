import 'package:quran/line_break.dart';
import 'package:quran/quran.dart' as quran;
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../models/mushaf_page_model.dart';

class MushafLocalDataSource {
  // Track current line and how many symbols we've placed on it
  int _currentLine = 1;
  int _symbolsOnCurrentLine = 0;

  MushafPageModel getPage(int pageNumber) {
    final pageData = quran.getPageData(pageNumber);
    final Map<int, int>? linesConfig = lineSymbolsCount[pageNumber];

    // Reset counters for the new page
    _currentLine = 1;
    _symbolsOnCurrentLine = 0;

    final List<String> ayahs = [];
    final List<int> surahHeadersIndexes = [];
    final List<String> surahNames = [];
    final List<bool> surahHasBasmala = [];
    final List<AyahIdentifier> ayahIdentifiers = [];

    for (var block in pageData) {
      int surah = block["surah"];
      int start = block["start"];
      int end = block["end"];

      if (start == 1) {
        surahNames.add(quran.getQcfSurahName(surah));
        bool hasBasmala = surah != 9 && pageNumber != 1;
        surahHasBasmala.add(hasBasmala);
        surahHeadersIndexes.add(ayahs.length);

        // When a Surah Header appears, it usually consumes a line.
        // If your lineSymbolsCount accounts for headers as lines,
        // increment _currentLine here if necessary.
      }

      for (int ayah = start; ayah <= end; ayah++) {
        String rawVerse = quran.getVerseQCF(surah, ayah);

        // 1. Apply your custom symbol/line break logic
        String verseWithBreaks = _injectLineBreaks(rawVerse, linesConfig);

        // 2. Apply your original preprocessing (uFB50 logic)
        String finalVerse = preprocessVerse(verseWithBreaks, ayah, start);

        ayahs.add(finalVerse);
        ayahIdentifiers.add(AyahIdentifier(surah: surah, ayah: ayah));
      }
    }

    return MushafPageModel(
      pageNumber: pageNumber,
      ayahs: ayahs,
      surahNames: surahNames,
      surahHeadersIndexes: surahHeadersIndexes,
      showBasmalaList: surahHasBasmala,
      ayahIdentifiers: ayahIdentifiers,
    );
  }

  String _injectLineBreaks(String verse, Map<int, int>? linesConfig) {
    if (linesConfig == null) return verse.replaceAll(' ', '');

    List<String> symbols = verse.trim().split(' ');
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < symbols.length; i++) {
      buffer.write(symbols[i]);
      _symbolsOnCurrentLine++;

      int? limit = linesConfig[_currentLine];

      // Check if we reached the end of the current line
      if (limit != null && _symbolsOnCurrentLine >= limit) {
        buffer.write('\n'); // Add the line break
        _currentLine++; // Move to next line config
        _symbolsOnCurrentLine = 0; // Reset counter for the new line
      }
    }

    return buffer.toString();
  }

  // Your original logic - UNCHANGED
  String preprocessVerse(String verse, int currentAyah, int startAyah) {
    String processed = verse.replaceAll(' ', '');
    if (currentAyah == startAyah && processed.isNotEmpty) {
      processed = '${processed.substring(0, 1)}\uFB50${processed.substring(1)}';
    }
    return processed;
  }
}
