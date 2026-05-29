import 'package:hive/hive.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
part 'hadith_hive_model.g.dart';

@HiveType(typeId: 4)
class HadithHiveModel extends HiveObject {
  @HiveField(0)
  final String hadithNumber;
  @HiveField(1)
  final String englishHadith;
  @HiveField(2)
  final String arabicHadith;
  @HiveField(3)
  final String englishHeader;
  @HiveField(4)
  final String arabicHeader;
  @HiveField(5)
  final String englishNarrator;
  @HiveField(6)
  final String status;
  @HiveField(7)
  final int pageNumber;
  @HiveField(8)
  final String bookSlug;
  @HiveField(9)
  final int chapterId;

  HadithHiveModel({
    required this.hadithNumber,
    required this.englishHadith,
    required this.arabicHadith,
    required this.englishNarrator,
    required this.arabicHeader,
    required this.englishHeader,
    required this.status,
    required this.pageNumber,
    required this.bookSlug,
    required this.chapterId,
  });

  Hadith toEntity() {
    return Hadith(
      hadithNumber: hadithNumber,
      englishHadith: englishHadith,
      arabicHadith: arabicHadith,
      englishNarrator: englishNarrator,
      englishHeader: englishHeader,
      arabicHeader: arabicHeader,
      chapterId: chapterId,

      status: HadithStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => HadithStatus.daeef,
      ),
    );
  }

  factory HadithHiveModel.fromEntity(Hadith entity, int page, String slug) {
    return HadithHiveModel(
      hadithNumber: entity.hadithNumber,
      englishHadith: entity.englishHadith,
      arabicHadith: entity.arabicHadith,
      englishNarrator: entity.englishNarrator,
      arabicHeader: entity.arabicHeader,
      englishHeader: entity.englishHeader,
      status: entity.status.name,
      pageNumber: page,
      bookSlug: slug,
      chapterId: entity.chapterId,
    );
  }
}
