import '../../../quran_playback/domain/entities/ayah_identifier.dart';

class MushafPageEntity {
  final int pageNumber;
  final List<String> ayahs;
  final String? surahName;
  final List<String> surahNames;
  final List<int> surahHeadersIndexes;
  final List<int> basmalaIndexes;
  final List<bool> showBasmalaList;
  final List<AyahIdentifier> ayahIdentifiers;

  MushafPageEntity({
    required this.pageNumber,
    required this.ayahs,
    this.surahName,
    required this.surahNames,
    required this.surahHeadersIndexes,
    required this.showBasmalaList,
    required this.ayahIdentifiers,
    required this.basmalaIndexes,
  });
}
