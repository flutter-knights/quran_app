import '../../../../core/usecases/usecase.dart';
import '../entities/surah_entity.dart';
import '../repositories/surah_repo.dart';

class GetSurahList extends UseCase<List<SurahEntity>, NoParams> {
  final SurahRepository repository;
  GetSurahList(this.repository);

  @override
  Future<List<SurahEntity>> call(NoParams) {
    return repository.getAllSurahs();
  }
}
