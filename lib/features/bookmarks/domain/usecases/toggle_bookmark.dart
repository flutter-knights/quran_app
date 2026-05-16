import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../repositories/bookmark_repository.dart';

class ToggleBookmark {
  ToggleBookmark(this.repository);
  final BookmarkRepository repository;

  Future<Either<Failure, bool>> call(AyahIdentifier ayah) =>
      repository.toggle(ayah);
}
