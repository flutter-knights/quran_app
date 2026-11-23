import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../surah/domain/usecases/get_mushaf_page.dart';
import '../entities/share_card_content.dart';

class GetShareCardContent {
  GetShareCardContent({
    required GetMushafPage getMushafPage,
    required QuranPageService pageService,
  }) : _getMushafPage = getMushafPage,
       _pageService = pageService;

  final GetMushafPage _getMushafPage;
  final QuranPageService _pageService;

  Future<Either<Failure, ShareCardContent>> call(AyahIdentifier ayah) async {
    final page = _pageService.getPageForAyah(ayah.surah, ayah.ayah);
    final startPage = _pageService.getPageForAyah(ayah.surah, 1);
    final pageResult = await _getMushafPage(page);
    final startResult = startPage == page
        ? pageResult
        : await _getMushafPage(startPage);

    return pageResult.flatMap(
      (pageEntity) => startResult.flatMap((startEntity) {
        if (!pageEntity.ayahs.any((bound) => bound.ayah == ayah)) {
          return Left(NotFoundFailure('${ayah.surah}:${ayah.ayah}'));
        }
        return Right(
          ShareCardContent(
            ayah: ayah,
            page: page,
            pageBounds: pageEntity.ayahs,
            startPage: startPage,
            startPageBounds: startEntity.ayahs,
          ),
        );
      }),
    );
  }
}
