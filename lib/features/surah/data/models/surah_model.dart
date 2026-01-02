import '../../domain/entities/surah_entity.dart';

class SurahModel extends SurahEntity {
  final String englishNameTranslation;
  SurahModel({
    required super.number,
    required super.name,
    required super.englishName,
    required super.numberOfAyahs,
    required super.revelationType,
    required super.pageNumber,
    required this.englishNameTranslation,
    required super.qcfSurahName,
  });

  factory SurahModel.fromJson(Map<String, dynamic> json) {
    return SurahModel(
      number: json["number"],
      name: "سُورَةُ ${json["name"]}",
      englishName: json["englishName"],
      englishNameTranslation: json["englishNameTranslation"],
      numberOfAyahs: json["numberOfAyahs"],
      revelationType: json["revelationType"],
      pageNumber: json["pageNumber"],
      qcfSurahName: json["qcfSurahName"],
    );
  }
}
