class MushafPageEntity {
  final int pageNumber;
  final List<String> ayahs;
  final String? surahName;
  final List<String> surahNames;
  final List<int> surahHeadersIndexes;
  final List<bool> showBasmalaList;

  MushafPageEntity({
    required this.pageNumber,
    required this.ayahs,
    this.surahName,
    required this.surahNames,
    required this.surahHeadersIndexes,
    required this.showBasmalaList,
  });
}
