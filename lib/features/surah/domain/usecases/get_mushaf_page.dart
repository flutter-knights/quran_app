import '../entities/mushaf_page_entity.dart';
import '../repositories/mushaf_repo.dart';

class GetMushafPage {
  final MushafRepository repository;

  GetMushafPage(this.repository);

  Future<MushafPageEntity> call(int pageNumber) {
    return repository.getPage(pageNumber);
  }
}
