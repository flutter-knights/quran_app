import '../../../../core/usecases/usecase.dart';
import '../entities/mushaf_page_entity.dart';
import '../repositories/mushaf_repo.dart';

class GetMushafPage extends UseCase<MushafPageEntity, int> {
  final MushafRepository repository;

  GetMushafPage(this.repository);

  @override
  Future<MushafPageEntity> call(int pageNumber) {
    return repository.getPage(pageNumber);
  }
}
