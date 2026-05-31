import 'package:equatable/equatable.dart';

enum JumpKind { page, juz }

/// A "go to page N" / "go to juzʼ N" shortcut shown when the query is numeric.
class JumpSuggestion extends Equatable {
  final JumpKind kind;
  final int number; // the page or juzʼ number the user typed
  final int page; // mushaf page to navigate to
  const JumpSuggestion({
    required this.kind,
    required this.number,
    required this.page,
  });

  @override
  List<Object?> get props => [kind, number, page];
}

class SurahResult extends Equatable {
  final int number;
  final String arabicName;
  final String englishName;
  final int ayahCount;
  final String revelationPlace; // 'Makkah' / 'Madinah'
  final int page;
  const SurahResult({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.ayahCount,
    required this.revelationPlace,
    required this.page,
  });

  @override
  List<Object?> get props =>
      [number, arabicName, englishName, ayahCount, revelationPlace, page];
}

class AyahResult extends Equatable {
  final int surah;
  final int ayah;
  final String text;
  final String surahArabicName;
  final int page;
  const AyahResult({
    required this.surah,
    required this.ayah,
    required this.text,
    required this.surahArabicName,
    required this.page,
  });

  @override
  List<Object?> get props => [surah, ayah, text, surahArabicName, page];
}

/// Grouped search output. [ayahTotalMatches] may exceed `ayahs.length` when the
/// display cap kicks in — the UI shows a "+N more" note instead of truncating
/// silently.
class SearchResults extends Equatable {
  final List<JumpSuggestion> suggestions;
  final List<SurahResult> surahs;
  final List<AyahResult> ayahs;
  final int ayahTotalMatches;

  const SearchResults({
    required this.suggestions,
    required this.surahs,
    required this.ayahs,
    required this.ayahTotalMatches,
  });

  static const SearchResults empty = SearchResults(
    suggestions: [],
    surahs: [],
    ayahs: [],
    ayahTotalMatches: 0,
  );

  bool get isEmpty =>
      suggestions.isEmpty && surahs.isEmpty && ayahs.isEmpty;

  @override
  List<Object?> get props =>
      [suggestions, surahs, ayahs, ayahTotalMatches];
}
