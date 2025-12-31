import '../../domain/entities/surah_entity.dart';
import '../../domain/repositories/surah_repo.dart';
import '../datasources/surah_local_data_source.dart';

class SurahRepositoryImpl implements SurahRepository {
  final SurahLocalDataSource local;

  SurahRepositoryImpl(this.local);

  @override
  Future<List<SurahEntity>> getAllSurahs() async {
    return await local.loadSurahs();
  }
}
