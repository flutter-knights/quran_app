import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';

abstract class BookmarkRepository {
  Future<Either<Failure, Set<AyahIdentifier>>> getAll();
  Future<Either<Failure, bool>> toggle(AyahIdentifier ayah);
  Future<Either<Failure, bool>> isBookmarked(AyahIdentifier ayah);
}
