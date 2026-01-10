import 'package:hive/hive.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
part 'hadith_hive_model.g.dart';

@HiveType(typeId: 4)
class HadithHiveModel extends HiveObject {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final String englishHadith;
  @HiveField(2)
  final String arabicHadith;
  @HiveField(3)
  final String englishNarrator;
  @HiveField(4)
  final String status;
  @HiveField(5)
  final int bookId;
  @HiveField(6)
  final int pageNumber;
  @HiveField(7)
  final String bookSlug; 

  HadithHiveModel({
    required this.id,
    required this.englishHadith,
    required this.arabicHadith,
    required this.englishNarrator,
    required this.status,
    required this.bookId,
    required this.pageNumber,
    required this.bookSlug,
  });

  Hadith toEntity() {
    return Hadith(
      id: id,
      englishHadith: englishHadith,
      arabicHadith: arabicHadith,
      englishNarrator: englishNarrator,
      chapterId: 0,
      bookId: bookId,
      status: HadithStatus.values.firstWhere((e) => e.name == status),
    );
  }

  factory HadithHiveModel.fromEntity(Hadith entity, int page, String slug) {
    return HadithHiveModel(
      id: entity.id,
      englishHadith: entity.englishHadith,
      arabicHadith: entity.arabicHadith,
      englishNarrator: entity.englishNarrator,
      status: entity.status.name,
      bookId: entity.bookId,
      pageNumber: page,
      bookSlug: slug,
    );
  }
}