import 'package:go_router/go_router.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

import 'app_router.dart';

void openNowPlaying(GoRouter router, AyahIdentifier? playing) {
  if (playing == null) return;
  final readerOpen = router.routerDelegate.currentConfiguration.matches.any(
    (m) =>
        m.matchedLocation == AppRouter.mushafPath ||
        m.matchedLocation == AppRouter.mushafImagePath,
  );
  if (readerOpen) return;
  router.push(AppRouter.mushafPath, extra: MushafArgs.nowPlaying(playing));
}
