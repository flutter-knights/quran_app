import '../../domain/entities/mushaf_page_entity.dart';

class MushafPageModel extends MushafPageEntity {
  MushafPageModel({
    required super.pageNumber,
    required super.ayahs,
    super.surahName,
    required super.surahNames,
    required super.surahHeadersIndexes,
    required super.showBasmalaList,
  });
}
