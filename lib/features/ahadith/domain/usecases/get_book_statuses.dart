import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class GetBookStatuses {
  GetBookStatuses(this._repo);
  final AhadithRepository _repo;

  Set<HadithStatus> call(String bookSlug) => _repo.getBookStatuses(bookSlug);
}
