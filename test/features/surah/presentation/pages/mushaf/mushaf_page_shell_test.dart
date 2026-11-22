import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
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

AyahBoundEntity _bound(AyahIdentifier a) => AyahBoundEntity(
  ayah: a,
  lines: const [NormalizedRect(x: 0.1, y: 0.1, w: 0.8, h: 0.05)],
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
  }) async {
    final mushaf = FakeMushaf(state ?? _state());
    addTearDown(mushaf.close);
    final h = await pumpMushafPage(
      tester,
      args,
      mushaf: mushaf,
      playback: FakePlayback(playback),
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
}
