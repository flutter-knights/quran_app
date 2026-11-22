import 'package:dartz/dartz.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../surah/domain/usecases/get_mushaf_page.dart';

const _lastPage = 604;

Future<AyahIdentifier?> Function(int page) firstAyahOfPage(
  GetMushafPage getPage,
) => (page) async {
  if (page < 1 || page > _lastPage) return null;
  final entity = (await getPage(
    page,
  )).getOrElse(() => throw CacheException('mushaf page $page failed to load'));
  return entity.ayahs.where((b) => b.ayah.ayah > 0).firstOrNull?.ayah;
};
