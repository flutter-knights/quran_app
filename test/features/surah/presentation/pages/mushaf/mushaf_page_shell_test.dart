import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/constants/leaf_tap_action.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/player_leaf.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reader_foot.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/running_head.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

import '../../../../bookmarks/place_fakes.dart';
import '../../../../notifications/presentation/alerts_test_harness.dart';
import '../../../../tafsir/tafsir_fakes.dart';
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

class _PageMap implements QuranPageService {
  _PageMap(this.pages);

  final Map<AyahIdentifier, int> pages;

  @override
  int getPageForAyah(int surah, int ayah) =>
      pages[AyahIdentifier(surah: surah, ayah: ayah)] ?? 7;

  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

class _BoundsRepo implements MushafRepository {
  _BoundsRepo(this.ayahs);

  final List<AyahBoundEntity> ayahs;

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: ayahs));
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
    FakeFasilCubit? fawasil,
    FakeSavedAyatCubit? saved,
    FakeTafsirCubit? tafsir,
    LastRead? stored,
  }) async {
    final mushaf = FakeMushaf(state ?? _state());
    addTearDown(mushaf.close);
    final h = await pumpMushafPage(
      tester,
      args,
      mushaf: mushaf,
      playback: FakePlayback(playback),
      settings: settings,
      fawasil: fawasil,
      saved: saved,
      tafsir: tafsir,
      stored: stored,
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

    expect(mushaf.jumps.map((j) => j.$1), [120]);
    expect(mushaf.state.currentPage, 120);
    expect(mushaf.setPages.where((c) => c.$2), isEmpty);
  });

  group('فواصل', () {
    const imran6 = AyahIdentifier(surah: 3, ayah: 6);
    const imran7 = AyahIdentifier(surah: 3, ayah: 7);

    FakeFasilCubit seeded(Map<FasilSlot, AyahIdentifier> at) => FakeFasilCubit(
      FasilState(
        slots: {for (final e in at.entries) e.key: fasilPlace(e.key, e.value)},
        loaded: true,
      ),
    );

    testWidgets('انتقال in the chooser jumps in place with the ayah selected', (
      tester,
    ) async {
      final (mushaf, _) = await pump(
        tester,
        state: _state(page: 2),
        args: const MushafArgs(page: 2),
        fawasil: seeded({FasilSlot.hifz: imran6}),
      );

      await tester.tap(find.byKey(const ValueKey('fasil-cluster')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fasil-go-hifz')));
      await tester.pumpAndSettle();

      expect(mushaf.jumps.last, (50, imran6));
    });

    testWidgets(
      'the leaf فاصل opens the chooser preselecting the slot on this page',
      (tester) async {
        final sl = GetIt.instance;
        sl.unregister<GetMushafPage>();
        sl.registerSingleton<GetMushafPage>(
          GetMushafPage(_BoundsRepo([_bound(imran6), _bound(imran7, y: 0.5)])),
        );
        final fawasil = seeded({FasilSlot.hifz: imran6});
        final (mushaf, _) = await pump(
          tester,
          state: _state(page: 50),
          args: const MushafArgs(page: 50),
          fawasil: fawasil,
        );
        mushaf.push(_state(page: 50, selected: imran7));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('leaf-fasil')));
        await tester.pumpAndSettle();

        expect(
          tester.widget(find.byKey(const ValueKey('fasil-move-hifz'))),
          isA<FilledButton>(),
        );
        expect(find.text('نقل الحفظ إلى هنا'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('fasil-move-hifz')));
        await tester.pumpAndSettle();

        expect(fawasil.moves.last, (FasilSlot.hifz, imran7));
      },
    );

    testWidgets('moving a فاصل confirms and تراجع restores it', (tester) async {
      final fawasil = seeded({FasilSlot.wird: _a5});
      final previous = fawasil.state.slots[FasilSlot.wird];
      final (mushaf, _) = await pump(tester, fawasil: fawasil);
      mushaf.push(_state(selected: imran7));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('fasil-cluster')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fasil-move-wird')));
      await tester.pumpAndSettle();

      expect(fawasil.moves.last, (FasilSlot.wird, imran7));
      expect(find.text('نُقل فاصل الورد إلى آل عمران ٧'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();

      expect(fawasil.restores.last, (FasilSlot.wird, previous));
    });

    testWidgets('the فاصل notice leaves by itself', (tester) async {
      final fawasil = seeded({FasilSlot.wird: _a5});
      final (mushaf, _) = await pump(tester, fawasil: fawasil);
      mushaf.push(_state(selected: imran7));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('fasil-cluster')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fasil-move-wird')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed فاصل move shows the error and no undo', (
      tester,
    ) async {
      final fawasil = seeded({FasilSlot.wird: _a5})..failMove = true;
      final (mushaf, _) = await pump(tester, fawasil: fawasil);
      mushaf.push(_state(selected: imran7));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('fasil-cluster')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fasil-move-wird')));
      await tester.pumpAndSettle();

      expect(find.text('تعذّر الحفظ، حاول مرة أخرى'), findsOneWidget);
      expect(find.text('تراجع'), findsNothing);
    });

    group('the chooser preselect', () {
      const imran1 = AyahIdentifier(surah: 3, ayah: 1);
      const banner = AyahIdentifier(surah: 3, ayah: 0);

      FakeFasilCubit onPageFifty() {
        final sl = GetIt.instance;
        sl.unregister<GetMushafPage>();
        sl.registerSingleton<GetMushafPage>(
          GetMushafPage(
            _BoundsRepo([_bound(imran1, y: 0.1), _bound(imran6, y: 0.5)]),
          ),
        );
        return seeded({FasilSlot.wird: imran1, FasilSlot.hifz: imran6});
      }

      Future<FakeMushaf> pumpOnPageFifty(
        WidgetTester tester, {
        AyahIdentifier? selected,
      }) async {
        final (mushaf, _) = await pump(
          tester,
          state: _state(page: 50, selected: selected),
          args: const MushafArgs(page: 50),
          fawasil: onPageFifty(),
        );
        return mushaf;
      }

      bool filled(WidgetTester tester, FasilSlot slot) =>
          tester.widget(find.byKey(ValueKey('fasil-move-${slot.name}')))
              is FilledButton;

      testWidgets('a tail preselects its own فاصل', (tester) async {
        await pumpOnPageFifty(tester, selected: imran6);

        await tester.tap(find.byKey(const ValueKey('fasil-tail-wird')));
        await tester.pumpAndSettle();

        expect(filled(tester, FasilSlot.wird), isTrue);
        expect(filled(tester, FasilSlot.hifz), isFalse);
        expect(find.text('نقل الورد إلى هنا'), findsOneWidget);
      });

      testWidgets('the cluster preselects the فاصل before the ayah', (
        tester,
      ) async {
        await pumpOnPageFifty(tester, selected: imran6);

        await tester.tap(find.byKey(const ValueKey('fasil-cluster')));
        await tester.pumpAndSettle();

        expect(filled(tester, FasilSlot.hifz), isTrue);
        expect(filled(tester, FasilSlot.wird), isFalse);
        expect(find.text('نقل الحفظ إلى هنا'), findsOneWidget);
      });

      testWidgets('a banner selection offers no move buttons', (tester) async {
        await pumpOnPageFifty(tester, selected: banner);

        await tester.tap(find.byKey(const ValueKey('fasil-cluster')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('fasil-row-hifz')), findsOneWidget);
        expect(find.byKey(const ValueKey('fasil-move-hifz')), findsNothing);
        expect(find.byKey(const ValueKey('fasil-move-wird')), findsNothing);
      });

      testWidgets('no selection offers no move buttons', (tester) async {
        await pumpOnPageFifty(tester);

        await tester.tap(find.byKey(const ValueKey('fasil-tail-hifz')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('fasil-row-hifz')), findsOneWidget);
        expect(find.byKey(const ValueKey('fasil-move-hifz')), findsNothing);
      });
    });

    testWidgets('placing an unset فاصل says وُضع', (tester) async {
      final fawasil = seeded({FasilSlot.hifz: imran6});
      final (mushaf, _) = await pump(tester, fawasil: fawasil);
      mushaf.push(_state(selected: _a5));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('fasil-cluster')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fasil-move-wird')));
      await tester.pumpAndSettle();

      expect(find.text('وُضع فاصل الورد عند البقرة ٥'), findsOneWidget);
    });
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

  testWidgets('menu places opens the sheet and a saved ayah jumps in place', (
    tester,
  ) async {
    final saved = FakeSavedAyatCubit(
      SavedAyatState(items: [savedPlace(_a5)], loaded: true),
    );
    final (mushaf, _) = await pump(tester, saved: saved);

    await tester.tap(find.byKey(const ValueKey('foot-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-tile-places')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('places-saved-2:5')));
    await tester.tap(find.byKey(const ValueKey('places-saved-2:5')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(mushaf.jumps.last, (2, _a5));
  });

  testWidgets('continue reading in the sheet jumps without a selection', (
    tester,
  ) async {
    final (mushaf, _) = await pump(tester, stored: const LastRead(page: 50));

    await tester.tap(find.byKey(const ValueKey('foot-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-tile-places')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('places-continue')),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(mushaf.jumps.last, (50, null));
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

    expect(mushaf.jumps.map((j) => j.$1), [120, 7]);
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

  Rect pageBox(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byType(MushafPageView),
          matching: find.byType(AspectRatio),
        )
        .first,
  );

  final fullPage = [
    _bound(_a6),
    _bound(const AyahIdentifier(surah: 2, ayah: 20), y: 0.9148),
  ];

  testWidgets('the return chip never covers the last line of the page', (
    tester,
  ) async {
    await pump(tester, state: _state(ayahs: fullPage));
    await jumpFromMenu(tester, '120');

    final chip = tester.getRect(find.byKey(const ValueKey('notice-chip')));
    final box = pageBox(tester);
    final lastLineBottom = box.top + box.height * 0.9648;
    expect(find.text('العودة إلى صفحة ٧'), findsOneWidget);
    expect(chip.top, greaterThanOrEqualTo(lastLineBottom - 0.5));
    expect(
      box.top + box.height * 0.065,
      greaterThanOrEqualTo(tester.getRect(find.byType(RunningHead)).bottom),
    );
  });

  testWidgets('the first-open hint never covers the last line', (tester) async {
    await pump(
      tester,
      state: _state(ayahs: fullPage),
      settings: FakeSettings(hintSeen: false),
    );

    final chip = tester.getRect(find.byKey(const ValueKey('notice-chip')));
    final box = pageBox(tester);
    expect(chip.top, greaterThanOrEqualTo(box.top + box.height * 0.9648 - 0.5));
  });

  testWidgets('the player leaf slides the page for the ayah being recited', (
    tester,
  ) async {
    const low = AyahIdentifier(surah: 2, ayah: 20);
    await pump(
      tester,
      state: _state(
        playingAyah: low,
        ayahs: [_bound(_a6), _bound(low, y: 0.9)],
      ),
      playback: _playing,
    );

    final leaf = tester.getRect(find.byType(PlayerLeaf));
    final box = pageBox(tester);
    expect(slideOf(tester), lessThan(0));
    expect(box.top + box.height * 0.95, lessThanOrEqualTo(leaf.top + 0.5));
  });

  testWidgets('listening away never slides the page for the player leaf', (
    tester,
  ) async {
    const away = AyahIdentifier(surah: 3, ayah: 12);
    await pump(
      tester,
      state: _state(follow: false, playingAyah: away, ayahs: fullPage),
      playback: const PlaybackState(currentAyah: away, isPlaying: true),
    );

    expect(find.byType(PlayerLeaf), findsOneWidget);
    expect(slideOf(tester), 0);
  });

  testWidgets('a jump arrival with focusAyah marks the tap hint seen', (
    tester,
  ) async {
    const focus = AyahIdentifier(surah: 3, ayah: 7);
    final args = MushafArgs(
      page: 50,
      focusAyah: focus,
      origin: MushafOrigin.jump,
    );
    final settings = FakeSettings(hintSeen: false);
    await pump(
      tester,
      state: MushafState.initial(args),
      args: args,
      settings: settings,
    );

    expect(settings.markHintSeenCalls, 1);
    expect(find.text('اضغط على أي آية لترى معناها وأزرارها'), findsNothing);
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

  group('tafsir', () {
    const next = AyahIdentifier(surah: 2, ayah: 7);

    Future<void> openStudy(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('leaf-tafsir')));
      await tester.pumpAndSettle();
    }

    Future<void> tapStep(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('selecting an ayah loads its tafsir', (tester) async {
      final (mushaf, h) = await pump(tester);

      mushaf.select(_a6);
      await tester.pumpAndSettle();

      expect(h.tafsir.loads, [_a6]);
    });

    testWidgets('a jump arrival with focusAyah loads its tafsir', (
      tester,
    ) async {
      final (_, h) = await pump(
        tester,
        state: _state(selected: _a6),
        args: const MushafArgs(page: 7, focusAyah: _a6),
      );

      expect(h.tafsir.loads, [_a6]);
    });

    testWidgets('clearing the selection cancels the tafsir request', (
      tester,
    ) async {
      final (mushaf, h) = await pump(tester, state: _state(selected: _a6));
      expect(h.tafsir.cancels, 0);

      mushaf.clearSelection();
      await tester.pumpAndSettle();

      expect(h.tafsir.cancels, 1);
    });

    testWidgets('تفسير الآية opens the full detent and العودة إلى المصحف '
        'returns with the ayah still selected', (tester) async {
      final (mushaf, _) = await pump(tester, state: _state(selected: _a6));
      expect(find.byKey(const ValueKey('study-leaf')), findsNothing);

      await openStudy(tester);
      expect(find.byKey(const ValueKey('study-leaf')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('study-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('study-leaf')), findsNothing);
      expect(find.byKey(const ValueKey('leaf-tafsir')), findsOneWidget);
      expect(mushaf.state.selectedAyah, _a6);
    });

    testWidgets('returning from the full detent leaves the page where it '
        'was', (tester) async {
      const low = AyahIdentifier(surah: 2, ayah: 20);
      final (mushaf, _) = await pump(
        tester,
        state: _state(ayahs: [_bound(_a6), _bound(low, y: 0.9)]),
      );
      mushaf.select(low);
      await tester.pumpAndSettle();
      final before = slideOf(tester);
      expect(before, lessThan(0));

      await openStudy(tester);
      await tester.tap(find.byKey(const ValueKey('study-back')));
      await tester.pumpAndSettle();

      expect(slideOf(tester), before);
    });

    testWidgets('system back collapses the full detent first, then closes', (
      tester,
    ) async {
      final (mushaf, _) = await pump(
        tester,
        state: _state(selected: _a6),
        pushed: true,
      );
      await openStudy(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('study-leaf')), findsNothing);
      expect(mushaf.clearCalls, 0);
      expect(mushaf.state.selectedAyah, _a6);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(mushaf.clearCalls, 1);
      expect(find.byType(AyahLeaf), findsNothing);
    });

    testWidgets('الآية التالية keeps the full detent open and moves the '
        'selection', (tester) async {
      setUpMushafHarness(pageService: _PageMap({}));
      final (mushaf, h) = await pump(tester, state: _state(selected: _a6));
      await openStudy(tester);

      await tapStep(tester, 'study-next');

      expect(mushaf.steps, [(next, 7)]);
      expect(mushaf.state.selectedAyah, next);
      expect(find.byKey(const ValueKey('study-leaf')), findsOneWidget);
      expect(h.tafsir.loads.last, next);
    });

    testWidgets('stepping back onto the playing ayah on the same page '
        'resumes follow', (tester) async {
      setUpMushafHarness(pageService: _PageMap({}));
      final (mushaf, _) = await pump(
        tester,
        state: _state(selected: _a6, playingAyah: _a5),
      );
      await openStudy(tester);
      expect(mushaf.state.followPlayback, isFalse);

      await tapStep(tester, 'study-previous');

      expect(mushaf.state.selectedAyah, _a5);
      expect(mushaf.state.followPlayback, isTrue);
    });

    testWidgets('الآية التالية on the last ayah of a page turns the page '
        'behind', (tester) async {
      setUpMushafHarness(pageService: _PageMap({next: 8}));
      final (mushaf, _) = await pump(tester, state: _state(selected: _a6));
      await openStudy(tester);

      await tapStep(tester, 'study-next');

      expect(mushaf.steps.last, (next, 8));
      expect(mushaf.state.currentPage, 8);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        7,
      );
      expect(mushaf.state.jumpFrom, isNull);
      expect(find.byKey(const ValueKey('notice-chip')), findsNothing);
      expect(find.byKey(const ValueKey('study-leaf')), findsOneWidget);
    });

    testWidgets('stepping to another ayah scrolls the full detent back to '
        'the top', (tester) async {
      setUpMushafHarness(pageService: _PageMap({}));
      await pump(tester, state: _state(selected: _a6), textScale: 2);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      await openStudy(tester);
      double offset() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('study-leaf')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;

      await tester.ensureVisible(find.byKey(const ValueKey('study-next')));
      await tester.pumpAndSettle();
      expect(offset(), greaterThan(0));

      await tester.tap(find.byKey(const ValueKey('study-next')));
      await tester.pumpAndSettle();

      expect(offset(), 0);
    });

    testWidgets('a step to another page counts as a manual turn for '
        'last read', (tester) async {
      setUpMushafHarness(pageService: _PageMap({next: 8}));
      final args = MushafArgs(page: 7, origin: MushafOrigin.jump);
      final (_, h) = await pump(
        tester,
        state: _state(selected: _a6),
        args: args,
      );
      await openStudy(tester);

      await tapStep(tester, 'study-next');
      await tester.pump(const Duration(seconds: 1));

      expect(h.repo.saved?.page, 8);
    });

    testWidgets("the strip shows the ayah's own page, not the current "
        'page', (tester) async {
      const own = AyahIdentifier(surah: 3, ayah: 9);
      setUpMushafHarness(pageService: _PageMap({own: 51}));
      await pump(
        tester,
        state: _state(page: 50, selected: own),
        args: const MushafArgs(page: 50),
      );

      await openStudy(tester);

      expect(tester.widget<AyahStrip>(find.byType(AyahStrip)).page, 51);
    });

    testWidgets('the selection moving to a surah start closes the full '
        'detent and frees the compact leaf', (tester) async {
      const end = AyahIdentifier(surah: 4, ayah: 176);
      const basmala = AyahIdentifier(surah: 5, ayah: 0);
      final (mushaf, _) = await pump(
        tester,
        state: _state(selected: end, playingAyah: end),
        pushed: true,
      );
      await openStudy(tester);
      expect(find.byKey(const ValueKey('study-leaf')), findsOneWidget);

      mushaf.push(
        mushaf.state.copyWith(selectedAyah: basmala, playingAyah: basmala),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('study-leaf')), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(AyahLeaf),
          matching: find.byWidgetPredicate(
            (w) => w is ExcludeSemantics && w.excluding,
          ),
        ),
        findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(mushaf.clearCalls, 1);
    });

    testWidgets('opening the full detent on an ayah other than the playing '
        'one stops following', (tester) async {
      final (mushaf, _) = await pump(
        tester,
        state: _state(selected: _a6, playingAyah: _a5),
      );
      expect(mushaf.state.followPlayback, isTrue);

      await openStudy(tester);

      expect(mushaf.state.followPlayback, isFalse);
    });

    testWidgets('opening the full detent on the playing ayah keeps '
        'following until a step leaves it', (tester) async {
      setUpMushafHarness(pageService: _PageMap({}));
      final (mushaf, _) = await pump(
        tester,
        state: _state(selected: _a6, playingAyah: _a6),
      );

      await openStudy(tester);
      expect(mushaf.state.followPlayback, isTrue);

      await tapStep(tester, 'study-next');

      expect(mushaf.state.selectedAyah, next);
      expect(mushaf.state.followPlayback, isFalse);
    });

    testWidgets("the strip fills in from the page's ayat after a step "
        'to another page', (tester) async {
      setUpMushafHarness(pageService: _PageMap({next: 8}));
      final (mushaf, _) = await pump(tester, state: _state(selected: _a6));
      await openStudy(tester);

      mushaf.push(
        mushaf.state.copyWith(
          currentPage: 8,
          selectedAyah: next,
          pageAyahs: const [],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AyahStrip>(find.byType(AyahStrip)).lines, isEmpty);

      mushaf.push(mushaf.state.copyWith(pageAyahs: [_bound(next)]));
      await tester.pumpAndSettle();

      expect(
        tester.widget<AyahStrip>(find.byType(AyahStrip)).lines,
        isNotEmpty,
      );
    });

    testWidgets('with الخيارات the compact leaf has no tafsir line', (
      tester,
    ) async {
      await pump(
        tester,
        state: _state(selected: _a6),
        settings: FakeSettings(tapAction: LeafTapAction.options),
      );

      expect(find.byKey(const ValueKey('tafsir-lead')), findsNothing);
      expect(find.byKey(const ValueKey('leaf-tafsir')), findsOneWidget);
    });

    testWidgets('the full detent fits at 2x text', (tester) async {
      await pump(tester, state: _state(selected: _a6), textScale: 2);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();

      await openStudy(tester);

      expect(find.byKey(const ValueKey('study-leaf')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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

    testWidgets('the notice chips hide behind the full detent', (tester) async {
      await pump(
        tester,
        state: _state(
          page: 3,
          selected: high,
          ayahs: bounds(),
        ).copyWith(jumpFrom: 1),
        args: const MushafArgs(page: 3),
        settings: FakeSettings(mode: MushafReadingMode.scroll),
      );
      expect(find.byKey(const ValueKey('notice-chip')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('leaf-tafsir')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('study-leaf')), findsOneWidget);
      expect(find.byKey(const ValueKey('notice-chip')), findsNothing);
    });

    testWidgets('the return chip sits below the scrolling pages', (
      tester,
    ) async {
      await pump(
        tester,
        state: _state(page: 3, ayahs: bounds()),
        args: const MushafArgs(page: 3),
        settings: FakeSettings(mode: MushafReadingMode.scroll),
      );
      await jumpFromMenu(tester, '120');

      final chip = tester.getRect(find.byKey(const ValueKey('notice-chip')));
      expect(
        chip.top,
        greaterThanOrEqualTo(tester.getRect(find.byType(ListView)).bottom),
      );
    });

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

    testWidgets('the end of the mushaf can scroll above the leaf', (
      tester,
    ) async {
      final (mushaf, _) = await pump(
        tester,
        state: _state(page: 604, ayahs: bounds()),
        args: const MushafArgs(page: 604),
        settings: FakeSettings(mode: MushafReadingMode.scroll),
      );
      final position = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .position;
      final before = position.maxScrollExtent;

      mushaf.select(low);
      await tester.pumpAndSettle();

      final overlay = tester.getSize(find.byType(AyahLeaf)).height;
      expect(position.maxScrollExtent - before, overlay);
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

  group('last read while a new recitation loads', () {
    setUp(() => setUpMushafHarness(pageService: QuranPageServiceImpl()));

    testWidgets('the old ayah is not saved on a page it is not on', (
      tester,
    ) async {
      const old = AyahIdentifier(surah: 3, ayah: 12);
      final (mushaf, h) = await pump(
        tester,
        playback: const PlaybackState(currentAyah: old, isPlaying: true),
      );
      mushaf.playingPage = 7;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(h.repo.saved?.page, 7);
      expect(h.repo.saved?.ayah, isNull);
    });
  });
}
