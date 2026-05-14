import 'package:quran/line_break.dart';
import 'package:quran/quran.dart' as quran;
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../models/mushaf_page_model.dart';

class MushafLocalDataSource {
  const MushafLocalDataSource();

  MushafPageModel getPage(int pageNumber) {
    final pageData = quran.getPageData(pageNumber);
    final Map<int, int>? linesConfig = lineSymbolsCount[pageNumber];

    var currentLine = 1;
    var symbolsOnCurrentLine = 0;

    final List<String> ayahs = [];
    final List<int> surahHeadersIndexes = [];
    final List<int> basmalaIndexes = [];
    final List<String> surahNames = [];
    final List<bool> surahHasBasmala = [];
    final List<AyahIdentifier> ayahIdentifiers = [];

    for (final block in pageData) {
      final int surah = block['surah'];
      final int start = block['start'];
      final int end = block['end'];
      if (start == 0 && end == 0) {
        surahNames.add(quran.getQcfSurahName(surah));
        surahHeadersIndexes.add(ayahs.length);
        continue;
      }
      if (start == 0) {
        surahNames.add(quran.getQcfSurahName(surah));
        surahHeadersIndexes.add(ayahs.length);
      }

      if (start == 1) {
        final bool hasBasmala = surah != 9 && pageNumber != 1;
        surahHasBasmala.add(hasBasmala);
        if (hasBasmala) basmalaIndexes.add(ayahs.length);
      }

      for (int ayah = start; ayah <= end; ayah++) {
        if (ayah == 0) continue;

        final rawVerse = quran.getVerseQCF(surah, ayah);

        final (verseWithBreaks, nextLine, nextSymbols) = _injectLineBreaks(
          rawVerse,
          linesConfig,
          currentLine,
          symbolsOnCurrentLine,
        );
        currentLine = nextLine;
        symbolsOnCurrentLine = nextSymbols;

        final finalVerse = _preprocessVerse(verseWithBreaks, ayah, start);
        ayahs.add(finalVerse);
        ayahIdentifiers.add(AyahIdentifier(surah: surah, ayah: ayah));
      }
    }

    return MushafPageModel(
      pageNumber: pageNumber,
      ayahs: ayahs,
      surahNames: surahNames,
      surahHeadersIndexes: surahHeadersIndexes,
      basmalaIndexes: basmalaIndexes,
      showBasmalaList: surahHasBasmala,
      ayahIdentifiers: ayahIdentifiers,
    );
  }

  (String, int, int) _injectLineBreaks(
    String verse,
    Map<int, int>? linesConfig,
    int currentLine,
    int symbolsOnCurrentLine,
  ) {
    if (linesConfig == null) {
      return (verse.replaceAll(' ', ''), currentLine, symbolsOnCurrentLine);
    }
    final symbols = verse.trim().split(' ');
    final buffer = StringBuffer();
    var line = currentLine;
    var symbolsOnLine = symbolsOnCurrentLine;
    for (var i = 0; i < symbols.length; i++) {
      buffer.write(symbols[i]);
      symbolsOnLine++;
      final limit = linesConfig[line];
      if (limit != null && symbolsOnLine >= limit) {
        buffer.write('\n');
        line++;
        symbolsOnLine = 0;
      }
    }
    return (buffer.toString(), line, symbolsOnLine);
  }

  String _preprocessVerse(String verse, int currentAyah, int startAyah) {
    var processed = verse.replaceAll(' ', '');
    if (currentAyah == startAyah && processed.isNotEmpty) {
      processed = '${processed.substring(0, 1)}ﭐ${processed.substring(1)}';
    }
    return processed;
  }
}

/// Top-level entry point for `compute()`. Lives next to the data source so the
/// isolate doesn't pull the DI graph.
MushafPageModel parseMushafPageInIsolate(int pageNumber) {
  return const MushafLocalDataSource().getPage(pageNumber);
}
