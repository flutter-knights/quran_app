import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

import 'app_router.dart';

final nowPlayingResume = StreamController<void>.broadcast();

void openNowPlaying(GoRouter router, AyahIdentifier? playing) {
  if (playing == null) return;
  final matches = router.routerDelegate.currentConfiguration.matches;
  final reader = matches.lastIndexWhere(
    (m) =>
        m.matchedLocation == AppRouter.mushafPath ||
        m.matchedLocation == AppRouter.mushafImagePath,
  );
  if (reader == -1) {
    router.push(AppRouter.mushafPath, extra: MushafArgs.nowPlaying(playing));
    return;
  }
  for (var i = matches.length - 1; i > reader; i--) {
    router.pop();
  }
  nowPlayingResume.add(null);
}

StreamSubscription<bool> listenNowPlaying(
  Stream<bool> clicks,
  GoRouter router,
  AyahIdentifier? Function() playing,
) => clicks
    .where((clicked) => clicked)
    .listen((_) => openNowPlaying(router, playing()));
