import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';

/// Returns the PageView index the controller should animate to in response
/// to a [playingAyah] change, or null if no swap is needed.
int? computeAutoSwapTargetIndex({
  required AyahIdentifier? playingAyah,
  required int? currentPageIndex,
  required QuranPageService pageService,
}) {
  if (playingAyah == null) return null;
  if (currentPageIndex == null) return null;
  final target =
      pageService.getPageForAyah(playingAyah.surah, playingAyah.ayah) - 1;
  if (target == currentPageIndex) return null;
  return target;
}
