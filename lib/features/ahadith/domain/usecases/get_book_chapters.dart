import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class GetBookChapters {
  GetBookChapters(this._repo);
  final AhadithRepository _repo;

  List<Chapter> call(String bookSlug) => _repo.getBookChapters(bookSlug);
}
