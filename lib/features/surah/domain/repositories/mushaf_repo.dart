import '../entities/mushaf_page_entity.dart';

abstract class MushafRepository {
  Future<MushafPageEntity> getPage(int pageNumber);
}
