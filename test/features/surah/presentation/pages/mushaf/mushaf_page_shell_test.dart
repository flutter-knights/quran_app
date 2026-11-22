import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/player_leaf.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reader_foot.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/running_head.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

import '../../../../notifications/presentation/alerts_test_harness.dart';
import 'mushaf_page_harness.dart';

const _a5 = AyahIdentifier(surah: 2, ayah: 5);
const _a6 = AyahIdentifier(surah: 2, ayah: 6);
const _end = AyahIdentifier(surah: 2, ayah: 286);

class _SplitPageService implements QuranPageService {
  @override
  int getPageForAyah(int surah, int ayah) => surah == 3 ? 51 : 7;

  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

AyahBoundEntity _bound(AyahIdentifier a, {double y = 0.1}) => AyahBoundEntity(
  ayah: a,
  lines: [NormalizedRect(x: 0.1, y: y, w: 0.8, h: 0.05)],
);

MushafState _state({
  int page = 7,
  AyahIdentifier? selected,
  List<AyahBoundEntity>? ayahs,
  bool follow = true,
  AyahIdentifier? playingAyah,
}) => MushafState(
  currentPage: page,
  selectedAyah: selected,
  playingAyah: playingAyah,
  followPlayback: follow,
  pageAyahs:
      ayahs ?? [_bound(_a6), _bound(const AyahIdentifier(surah: 2, ayah: 16))],
);

const _playing = PlaybackState(
  requestedAyah: _a5,
  currentAyah: _a5,
  isPlaying: true,
);

void main() {
  setUpAll(loadAppFonts);
  setUp(setUpMushafHarness);

  Future<(FakeMushaf, MushafHarness)> pump(
    WidgetTester tester, {
    MushafState? state,
    PlaybackState playback = const PlaybackState(),
    MushafArgs args = const MushafArgs(page: 7),
    bool pushed = false,
    double textScale = 1.0,
    FakeSettings? settings,
  }) async {
    final mushaf = FakeMushaf(state ?? _state());
    addTearDown(mushaf.close);
    final h = await pumpMushafPage(
      tester,
      args,
      mushaf: mushaf,
      playback: FakePlayback(playback),
      settings: settings,
      pushed: pushed,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return (mushaf, h);
  }

  testWidgets('head and foot are always visible', (tester) async {
    await pump(tester);

    expect(find.byType(RunningHead), findsOneWidget);
    expect(find.byType(ReaderFoot), findsOneWidget);
  });

  testWidgets('page-turn buttons stay while a recitation plays', (
    tester,
  ) async {
    final (mushaf, _) = await pump(tester, playback: _playing);

    bool enabled(String key) =>
        tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed != null;
    expect(enabled('foot-previous'), isTrue);
    expect(enabled('foot-next'), isTrue);

    await tester.tap(find.byKey(const ValueKey('foot-next')));
    await tester.pumpAndSettle();

    expect(mushaf.setPages, contains((8, true)));
  });

  testWidgets('the player leaf shows during a recitation', (tester) async {
    await pump(tester, playback: _playing);

    expect(find.byType(PlayerLeaf), findsOneWidget);
    expect(find.byType(AyahLeaf), findsNothing);
  });

  testWidgets('tap while playing swaps in the ayah leaf, closing returns to '
      'the player', (tester) async {
    final (mushaf, _) = await pump(tester, playback: _playing);

    mushaf.push(mushaf.state.copyWith(selectedAyah: _a6));
    await tester.pumpAndSettle();
    expect(find.byType(AyahLeaf), findsOneWidget);
    expect(find.byType(PlayerLeaf), findsNothing);

    await tester.tap(find.byKey(const ValueKey('leaf-close')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerLeaf), findsOneWidget);
    expect(find.byType(AyahLeaf), findsNothing);
  });

  testWidgets('tap while paused does the same', (tester) async {
    final (mushaf, _) = await pump(
      tester,
      playback: const PlaybackState(currentAyah: _a5, isPaused: true),
    );

    mushaf.push(mushaf.state.copyWith(selectedAyah: _a6));
    await tester.pumpAndSettle();
    expect(find.byType(AyahLeaf), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('leaf-close')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerLeaf), findsOneWidget);
    expect(find.byType(AyahLeaf), findsNothing);
  });

  testWidgets('listen from here replaces the recitation and shows the player', (
    tester,
  ) async {
    final (mushaf, h) = await pump(
      tester,
      state: _state(selected: _a6),
      playback: _playing,
    );
    expect(find.byType(AyahLeaf), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('leaf-listen')));
    await tester.pumpAndSettle();

    expect(h.playback.playRanges, [(_a6, _end)]);
    expect(h.playback.state.currentAyah, _a6);
    expect(mushaf.state.selectedAyah, isNull);
    expect(find.byType(PlayerLeaf), findsOneWidget);
    expect(find.byType(AyahLeaf), findsNothing);
  });

  testWidgets('a recitation started while listening away keeps the page', (
    tester,
  ) async {
    const away = AyahIdentifier(surah: 3, ayah: 12);
    final notifier = ValueNotifier<AyahIdentifier?>(away);
    final mushaf = MushafCubit(
      args: const MushafArgs(page: 7),
      currentAyahNotifier: notifier,
      pageService: _SplitPageService(),
      getMushafPage: GetIt.instance<GetMushafPage>(),
    );
    addTearDown(mushaf.close);
    addTearDown(notifier.dispose);
    final h = await pumpMushafPage(
      tester,
      const MushafArgs(page: 7),
      mushaf: mushaf,
      playback: FakePlayback(
        const PlaybackState(currentAyah: away, isPlaying: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(mushaf.state.followPlayback, isFalse);

    mushaf.select(_a6);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leaf-listen')));
    await tester.pumpAndSettle();

    expect(h.playback.playRanges, [(_a6, _end)]);
    expect(notifier.value, away);
    expect(mushaf.state.followPlayback, isTrue);
    expect(mushaf.state.currentPage, 7);
  });

  testWidgets('the banner leaf plays the whole page and gives the slot to the '
      'player', (tester) async {
    const banner = AyahIdentifier(surah: 5, ayah: 0);
    const first = AyahIdentifier(surah: 4, ayah: 176);
    const last = AyahIdentifier(surah: 5, ayah: 2);
    final (mushaf, h) = await pump(
      tester,
      state: _state(
        page: 106,
        selected: banner,
        ayahs: [
          _bound(first),
          _bound(banner),
          _bound(const AyahIdentifier(surah: 5, ayah: 1)),
          _bound(last),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('leaf-page')));
    await tester.pumpAndSettle();

    expect(h.playback.playRanges, [(first, last)]);
    expect(mushaf.clearCalls, 1);
    expect(find.byType(PlayerLeaf), findsOneWidget);
    expect(find.byType(AyahLeaf), findsNothing);
  });

  testWidgets('the foot listen plays the selected ayah to the surah end', (
    tester,
  ) async {
    final (_, h) = await pump(tester, state: _state(selected: _a6));

    await tester.tap(find.byKey(const ValueKey('foot-listen')));
    await tester.pumpAndSettle();

    expect(h.playback.playRanges, [(_a6, _end)]);
  });

  testWidgets("the foot listen with nothing selected starts from the page's "
      'first ayah', (tester) async {
    final (_, h) = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('foot-listen')));
    await tester.pumpAndSettle();

    expect(h.playback.playRanges, [(_a6, _end)]);
  });

  testWidgets('system back closes an open leaf first', (tester) async {
    final (mushaf, _) = await pump(
      tester,
      state: _state(selected: _a6),
      pushed: true,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(mushaf.clearCalls, 1);
    expect(find.byType(AyahLeaf), findsNothing);
    expect(find.byType(MushafPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(MushafPage), findsNothing);
  });

  testWidgets('the head back leaves in one tap, even with a leaf open', (
    tester,
  ) async {
    await pump(tester, state: _state(selected: _a6), pushed: true);

    await tester.tap(find.byKey(const ValueKey('head-back')));
    await tester.pumpAndSettle();

    expect(find.byType(MushafPage), findsNothing);
  });

  testWidgets('listening-away shows in the player leaf', (tester) async {
    const away = AyahIdentifier(surah: 3, ayah: 12);
    final mushaf = FakeMushaf(_state(page: 7, follow: false, playingAyah: away))
      ..playingPage = 51;
    addTearDown(mushaf.close);
    await pumpMushafPage(
      tester,
      const MushafArgs(page: 7),
      mushaf: mushaf,
      playback: FakePlayback(
        const PlaybackState(currentAyah: away, isPlaying: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('يُتلى الآن: آل عمران ١٢، صفحة ٥١'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player-return')));
    await tester.pump();

    expect(mushaf.resumeCalls, 1);
  });

  testWidgets('skipping while listening away follows the ayah being started', (
    tester,
  ) async {
    final (mushaf, _) = await pump(
      tester,
      state: _state(follow: false, playingAyah: _a5),
      playback: _playing,
    );

    await tester.tap(find.byKey(const ValueKey('player-next')));
    await tester.pump();

    expect(mushaf.followFroms, [_a6]);
    expect(mushaf.resumeCalls, 0);
  });

  testWidgets('a playback that ends or fails drops the pending follow target', (
    tester,
  ) async {
    final (mushaf, h) = await pump(tester, playback: _playing);

    h.playback.push(const PlaybackState(error: 'offline'));
    await tester.pump();

    expect(mushaf.cancelFollowTargetCalls, 1);
  });

  testWidgets('menu jump moves in place once', (tester) async {
    final (mushaf, _) = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('foot-menu')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('menu-search')), '120');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('menu-go')));
    await tester.pumpAndSettle();

    expect(mushaf.jumps, [120]);
    expect(mushaf.state.currentPage, 120);
    expect(mushaf.setPages.where((c) => c.$2), isEmpty);
  });

  testWidgets('menu display opens the display sheet', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('foot-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-tile-display')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(DisplaySheet), findsOneWidget);
  });

  testWidgets('menu play page plays the page range', (tester) async {
    final (_, h) = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('foot-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-tile-play')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(h.playback.playRanges, [
      (_a6, const AyahIdentifier(surah: 2, ayah: 16)),
    ]);
  });

  testWidgets('the head names the running surah and the juz and hizb', (
    tester,
  ) async {
    await pump(
      tester,
      state: _state(
        page: 50,
        ayahs: [_bound(const AyahIdentifier(surah: 3, ayah: 1))],
      ),
    );

    final meta = GetIt.instance<QuranMetaService>().getPageMeta(50);
    final head = find.byType(RunningHead);
    expect(
      find.descendant(of: head, matching: find.text('آل عمران')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: head,
        matching: find.text(
          'الجزء ${'${meta.juz}'.toIndicNumerals('ar')}، الحزب ${'${meta.hizb}'.toIndicNumerals('ar')}',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the page box keeps its size between text scales', (
    tester,
  ) async {
    Size box() => tester.getSize(
      find
          .descendant(
            of: find.byType(MushafPageView),
            matching: find.byType(AspectRatio),
          )
          .first,
    );

    await pump(tester);
    final normal = box();
    await tester.pumpWidget(const SizedBox.shrink());

    await pump(tester, textScale: 2.0);

    expect(box(), normal);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jump arrival with focusAyah shows the ayah leaf', (
    tester,
  ) async {
    const focus = AyahIdentifier(surah: 3, ayah: 7);
    final args = MushafArgs(
      page: 50,
      focusAyah: focus,
      origin: MushafOrigin.jump,
    );
    await pump(tester, state: MushafState.initial(args), args: args);

    expect(find.byType(AyahLeaf), findsOneWidget);
    expect(find.text('آل عمران، الآية ٧'), findsOneWidget);
  });

  const downloadHint = 'يمكنك تنزيل السورة لتستمع دون إنترنت';
  const streaming = PlaybackState(
    requestedAyah: AyahIdentifier(surah: 3, ayah: 4),
    currentAyah: AyahIdentifier(surah: 3, ayah: 4),
    isPlaying: true,
    playedFromNetwork: true,
  );

  Future<void> jumpFromMenu(WidgetTester tester, String page) async {
    await tester.tap(find.byKey(const ValueKey('foot-menu')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('menu-search')), page);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('menu-go')));
    await tester.pumpAndSettle();
  }

  testWidgets('after a menu jump the chip offers the way back', (tester) async {
    final (mushaf, _) = await pump(tester);

    await jumpFromMenu(tester, '120');

    expect(find.text('العودة إلى صفحة ٧'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notice-chip')));
    await tester.pumpAndSettle();

    expect(mushaf.jumps, [120, 7]);
    expect(find.byKey(const ValueKey('notice-chip')), findsNothing);
  });

  testWidgets('a manual turn removes the return chip', (tester) async {
    await pump(tester);
    await jumpFromMenu(tester, '120');

    await tester.tap(find.byKey(const ValueKey('foot-next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notice-chip')), findsNothing);
  });

  testWidgets('first open shows the tap hint until فهمت', (tester) async {
    final settings = FakeSettings(hintSeen: false);
    await pump(tester, settings: settings);

    expect(find.text('اضغط على أي آية لترى معناها وأزرارها'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notice-action')));
    await tester.pumpAndSettle();

    expect(settings.markHintSeenCalls, 1);
    expect(find.byKey(const ValueKey('notice-chip')), findsNothing);
  });

  testWidgets('selecting an ayah marks the hint seen', (tester) async {
    final settings = FakeSettings(hintSeen: false);
    final (mushaf, _) = await pump(tester, settings: settings);

    mushaf.select(_a6);
    await tester.pumpAndSettle();

    expect(settings.markHintSeenCalls, 1);
  });

  testWidgets('the download hint downloads the playing surah', (tester) async {
    final settings = FakeSettings(downloadHintSeen: false);
    final (_, h) = await pump(tester, settings: settings);

    h.playback.push(streaming);
    await tester.pumpAndSettle();
    expect(find.text(downloadHint), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notice-chip')));
    await tester.pumpAndSettle();

    expect(h.downloads.downloads, [(Reciter.alafasy, 3)]);
    expect(settings.markDownloadHintSeenCalls, 1);
  });

  testWidgets('the download hint action only marks it seen', (tester) async {
    final settings = FakeSettings(downloadHintSeen: false);
    final (_, h) = await pump(tester, settings: settings);
    h.playback.push(streaming);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notice-action')));
    await tester.pumpAndSettle();

    expect(h.downloads.downloads, isEmpty);
    expect(settings.markDownloadHintSeenCalls, 1);
  });

  testWidgets('a seen download hint never shows', (tester) async {
    final settings = FakeSettings();
    final (_, h) = await pump(tester, settings: settings);

    h.playback.push(streaming);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notice-chip')), findsNothing);
    expect(settings.markDownloadHintSeenCalls, 0);
  });

  testWidgets('opening the reader mid-stream still shows the download hint', (
    tester,
  ) async {
    await pump(
      tester,
      playback: streaming,
      settings: FakeSettings(downloadHintSeen: false),
    );

    expect(find.text(downloadHint), findsOneWidget);
  });

  testWidgets('an audio error hides the download hint', (tester) async {
    final (_, h) = await pump(
      tester,
      playback: streaming,
      settings: FakeSettings(downloadHintSeen: false),
    );
    expect(find.byKey(const ValueKey('notice-chip')), findsOneWidget);

    h.playback.push(
      streaming.copyWith(
        error: 'x',
        requestedAyah: const AyahIdentifier(surah: 3, ayah: 4),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notice-chip')), findsNothing);
    expect(find.byKey(const ValueKey('player-retry')), findsOneWidget);
  });

  double slideOf(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(const ValueKey('page-slide')))
      .transform
      .getTranslation()
      .y;

  testWidgets('an ayah under the leaf slides the page up, one above it does '
      'not', (tester) async {
    const low = AyahIdentifier(surah: 2, ayah: 20);
    final (mushaf, _) = await pump(
      tester,
      state: _state(ayahs: [_bound(_a6), _bound(low, y: 0.9)]),
    );
    expect(slideOf(tester), 0);

    mushaf.select(low);
    await tester.pumpAndSettle();

    final overlay = tester.getSize(find.byType(AyahLeaf)).height;
    expect(slideOf(tester), lessThan(0));
    expect(slideOf(tester), greaterThanOrEqualTo(-overlay));

    mushaf.clearSelection();
    await tester.pumpAndSettle();
    mushaf.select(_a6);
    await tester.pumpAndSettle();

    expect(slideOf(tester), 0);
  });

  testWidgets('the raised page never covers the running head', (tester) async {
    const low = AyahIdentifier(surah: 2, ayah: 20);
    await pump(
      tester,
      state: _state(selected: low, ayahs: [_bound(_a6), _bound(low, y: 0.9)]),
      pushed: true,
    );
    expect(slideOf(tester), lessThan(0));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('page-slide')),
        matching: find.byType(ClipRect),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('head-back')));
    await tester.pumpAndSettle();

    expect(find.byType(MushafPage), findsNothing);
  });

  group('scroll mode', () {
    const high = AyahIdentifier(surah: 2, ayah: 6);
    const low = AyahIdentifier(surah: 2, ayah: 16);

    List<AyahBoundEntity> bounds() => [
      AyahBoundEntity(
        ayah: high,
        lines: const [NormalizedRect(x: 0.1, y: 0.1, w: 0.8, h: 0.05)],
      ),
      AyahBoundEntity(
        ayah: low,
        lines: const [NormalizedRect(x: 0.1, y: 0.85, w: 0.8, h: 0.05)],
      ),
    ];

    double pixels(WidgetTester tester) => tester
        .widget<ListView>(find.byType(ListView))
        .controller!
        .position
        .pixels;

    setUp(() => setUpMushafHarness(pageService: QuranPageServiceImpl()));

    testWidgets('an ayah under the leaf scrolls by the need, one above it '
        'does not', (tester) async {
      final (mushaf, _) = await pump(
        tester,
        state: _state(page: 3, ayahs: bounds()),
        args: const MushafArgs(page: 3),
        settings: FakeSettings(mode: MushafReadingMode.scroll),
      );
      final before = pixels(tester);

      mushaf.select(low);
      await tester.pumpAndSettle();

      final overlay = tester.getSize(find.byType(AyahLeaf)).height;
      expect(pixels(tester) - before, greaterThan(0));
      expect(pixels(tester) - before, lessThanOrEqualTo(overlay));
      expect(mushaf.setPages.where((c) => c.$2), isEmpty);

      final after = pixels(tester);
      mushaf.clearSelection();
      await tester.pumpAndSettle();
      mushaf.select(high);
      await tester.pumpAndSettle();

      expect(pixels(tester), after);
    });

    testWidgets('arrival with focusAyah slides once', (tester) async {
      final args = MushafArgs(
        page: 3,
        focusAyah: low,
        origin: MushafOrigin.jump,
      );
      await pump(
        tester,
        state: MushafState.initial(args).copyWith(pageAyahs: bounds()),
        args: args,
        settings: FakeSettings(mode: MushafReadingMode.scroll),
      );

      final extent = tester.widget<ListView>(find.byType(ListView)).itemExtent!;
      expect(pixels(tester), greaterThan(extent * 2));
      expect(find.byType(AyahLeaf), findsOneWidget);
    });

    testWidgets('a later overlay resize does not slide the page back', (
      tester,
    ) async {
      final args = MushafArgs(
        page: 3,
        focusAyah: low,
        origin: MushafOrigin.jump,
      );
      final (_, h) = await pump(
        tester,
        state: MushafState.initial(args).copyWith(pageAyahs: bounds()),
        args: args,
        settings: FakeSettings(
          mode: MushafReadingMode.scroll,
          downloadHintSeen: false,
        ),
      );
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      controller.jumpTo(controller.position.pixels - 60);
      await tester.pumpAndSettle();
      final scrolled = pixels(tester);
      final leafHeight = tester.getSize(find.byType(AyahLeaf)).height;

      h.playback.push(streaming);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notice-chip')), findsOneWidget);
      expect(tester.getSize(find.byType(AyahLeaf)).height, leafHeight);
      expect(pixels(tester), scrolled);
    });

    testWidgets('selecting another ayah under the leaf slides without a '
        'resize', (tester) async {
      final (mushaf, _) = await pump(
        tester,
        state: _state(page: 3, ayahs: bounds()),
        args: const MushafArgs(page: 3),
        settings: FakeSettings(mode: MushafReadingMode.scroll),
      );
      mushaf.select(high);
      await tester.pumpAndSettle();
      final before = pixels(tester);
      final overlay = tester.getSize(find.byType(AyahLeaf)).height;

      mushaf.select(low);
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AyahLeaf)).height, overlay);
      expect(pixels(tester) - before, greaterThan(0));
      expect(pixels(tester) - before, lessThanOrEqualTo(overlay));
    });
  });

  testWidgets('keep-awake turns on at entry and off on dispose', (
    tester,
  ) async {
    final (_, h) = await pump(tester);
    expect(h.wake.calls, [true]);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(h.wake.calls, [true, false]);
  });

  testWidgets('keep-awake stays off when the setting is off', (tester) async {
    final (_, h) = await pump(
      tester,
      settings: FakeSettings(keepScreenOn: false),
    );

    expect(h.wake.calls.where((on) => on), isEmpty);
  });

  testWidgets('switching keep-awake off while open releases the screen', (
    tester,
  ) async {
    final settings = FakeSettings();
    final (_, h) = await pump(tester, settings: settings);

    settings.updateKeepScreenOn(false);
    await tester.pump();

    expect(h.wake.calls, [true, false]);
  });
}
