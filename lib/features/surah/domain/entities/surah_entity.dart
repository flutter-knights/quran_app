class SurahEntity {
  final int number;
  final String name;
  final String englishName;
  final String qcfSurahName;
  final int numberOfAyahs;
  final String revelationType;
  final int pageNumber;

  SurahEntity({
    required this.number,
    required this.name,
    required this.englishName,
    required this.numberOfAyahs,
    required this.revelationType,
    required this.pageNumber,
    required this.qcfSurahName,
  });
}
