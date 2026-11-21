import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/router/now_playing_route.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

void main() {
  const playing = AyahIdentifier(surah: 3, ayah: 4);
  late GoRouter router;
  Object? extra;
  var mushafBuilds = 0;

  Future<void> pumpRouter(WidgetTester tester) async {
    extra = null;
    mushafBuilds = 0;
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: AppRouter.mushafPath,
          builder: (_, state) {
            mushafBuilds++;
            extra = state.extra;
            return const Text('mushaf');
          },
        ),
        GoRoute(
          path: AppRouter.bookmarksPath,
          builder: (_, _) => const Text('bookmarks'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  int depth() => router.routerDelegate.currentConfiguration.matches.length;

  testWidgets('from home it opens the playing page', (tester) async {
    await pumpRouter(tester);
    openNowPlaying(router, playing);
    await tester.pumpAndSettle();
    final args = extra as MushafArgs;
    expect(args.page, 50);
    expect(args.origin, MushafOrigin.jump);
    expect(args.focusAyah, isNull);
  });

  testWidgets('on the reader it does not stack a second one', (tester) async {
    await pumpRouter(tester);
    router.push(AppRouter.mushafPath);
    await tester.pumpAndSettle();
    final before = depth();
    openNowPlaying(router, playing);
    await tester.pumpAndSettle();
    expect(depth(), before);
    expect(mushafBuilds, 1);
  });

  testWidgets(
    'under a route pushed from the reader it does not stack a second one',
    (tester) async {
      await pumpRouter(tester);
      router.push(AppRouter.mushafPath);
      await tester.pumpAndSettle();
      router.push(AppRouter.bookmarksPath);
      await tester.pumpAndSettle();
      final before = depth();
      openNowPlaying(router, playing);
      await tester.pumpAndSettle();
      expect(depth(), before);
      expect(find.text('mushaf', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets('with nothing playing it stays put', (tester) async {
    await pumpRouter(tester);
    openNowPlaying(router, null);
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/');
    expect(mushafBuilds, 0);
  });

  group('listenNowPlaying', () {
    late StreamController<bool> clicks;
    late StreamSubscription<bool> sub;
    AyahIdentifier? current;

    Future<void> start(WidgetTester tester) async {
      await pumpRouter(tester);
      clicks = StreamController<bool>();
      sub = listenNowPlaying(clicks.stream, router, () => current);
      addTearDown(sub.cancel);
      addTearDown(clicks.close);
    }

    testWidgets('a false click does nothing', (tester) async {
      current = playing;
      await start(tester);
      clicks.add(false);
      await tester.pumpAndSettle();
      expect(mushafBuilds, 0);
    });

    testWidgets('a true click opens the page playing at that moment', (
      tester,
    ) async {
      current = null;
      await start(tester);
      current = playing;
      clicks.add(true);
      await tester.pumpAndSettle();
      expect((extra as MushafArgs).page, 50);
    });

    testWidgets('after cancel a click does nothing', (tester) async {
      current = playing;
      await start(tester);
      unawaited(sub.cancel());
      clicks.add(true);
      await tester.pumpAndSettle();
      expect(mushafBuilds, 0);
    });
  });
}
