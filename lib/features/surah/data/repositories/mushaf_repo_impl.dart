import '../../domain/entities/mushaf_page_entity.dart';
import '../../domain/repositories/mushaf_repo.dart';
import '../datasources/mushaf_local_data_source.dart';

class MushafRepositoryImpl implements MushafRepository {
  final MushafLocalDataSource datasource;

  MushafRepositoryImpl(this.datasource);

  @override
  Future<MushafPageEntity> getPage(int pageNumber) async {
    return datasource.getPage(pageNumber);
  }
}
