import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../repositories/bookmark_repository.dart';

class GetBookmarks {
  GetBookmarks(this.repository);
  final BookmarkRepository repository;

  Future<Either<Failure, Set<AyahIdentifier>>> call() => repository.getAll();
}
