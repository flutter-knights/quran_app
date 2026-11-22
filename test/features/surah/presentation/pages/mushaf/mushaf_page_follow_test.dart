import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/config/router/now_playing_route.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';

import '../../../../notifications/presentation/alerts_test_harness.dart';
import 'mushaf_page_harness.dart';

class _RecordingMushaf extends MushafCubit {
  _RecordingMushaf({
    required super.args,
    required super.currentAyahNotifier,
    required super.pageService,
    required super.getMushafPage,
  });

  final calls = <(int, bool)>[];
  final jumps = <int>[];

  @override
  void setPage(int page, {required bool byUser}) {
    calls.add((page, byUser));
    super.setPage(page, byUser: byUser);
  }

  @override
  void jumpTo(int page) {
    jumps.add(page);
    super.jumpTo(page);
  }
}

class _SurahIsPageService implements QuranPageService {
  @override
  int getPageForAyah(int s, int a) => s;
  @override
  AyahIdentifier? getFirstAyahOfPage(int p) => null;
}

void main() {
  final sl = GetIt.instance;
  late ValueNotifier<AyahIdentifier?> playing;
  late _RecordingMushaf mushaf;

  const a50 = AyahIdentifier(surah: 50, ayah: 1);
  const a51 = AyahIdentifier(surah: 51, ayah: 1);
  const a51b = AyahIdentifier(surah: 51, ayah: 2);

  setUpAll(loadAppFonts);

  setUp(() {
    setUpMushafHarness(pageService: _SurahIsPageService());
    playing = ValueNotifier(null);
    mushaf = _RecordingMushaf(
      args: const MushafArgs(page: 50),
      currentAyahNotifier: playing,
      pageService: sl<QuranPageService>(),
      getMushafPage: sl<GetMushafPage>(),
    );
  });

  tearDown(() async {
    await mushaf.close();
    playing.dispose();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpMushafPage(tester, const MushafArgs(page: 50), mushaf: mushaf);
    await tester.pump();
    playing.value = a50;
    mushaf.toggleSelection(a50);
    await tester.pump();
    mushaf.calls.clear();
  }

  testWidgets('a page in page mode keeps its aspect in a tall viewport', (
    tester,
  ) async {
    await pumpPage(tester);

    final box = find.descendant(
      of: find.byType(PageView),
      matching: find.byType(AspectRatio),
    );
    final size = tester.getSize(box.first);

    expect(size.width / size.height, closeTo(mushafPageAspect, 1e-5));
    expect(size.height, lessThan(800));
  });

  testWidgets('a follow turn to the next page keeps the selection', (
    tester,
  ) async {
    await pumpPage(tester);

    playing.value = a51;
    await tester.pumpAndSettle();

    expect(mushaf.state.currentPage, 51);
    expect(mushaf.state.selectedAyah, a51);
    expect(mushaf.state.followPlayback, isTrue);
    expect(mushaf.calls, [(51, false)]);
  });

  testWidgets('a swipe after the follow turn is manual and stops following', (
    tester,
  ) async {
    await pumpPage(tester);
    playing.value = a51;
    await tester.pumpAndSettle();
    mushaf.calls.clear();

    await tester.fling(find.byType(PageView), const Offset(300, 0), 2000);
    await tester.pumpAndSettle();

    expect(mushaf.calls, [(52, true)]);
    expect(mushaf.state.followPlayback, isFalse);
    expect(mushaf.state.selectedAyah, isNull);
  });

  testWidgets(
    'the notification tap signal resumes follow on the playing page',
    (tester) async {
      await pumpPage(tester);
      await tester.fling(find.byType(PageView), const Offset(300, 0), 2000);
      await tester.pumpAndSettle();
      expect(mushaf.state.followPlayback, isFalse);
      expect(mushaf.state.currentPage, isNot(50));

      nowPlayingResume.add(null);
      await tester.pumpAndSettle();

      expect(mushaf.state.followPlayback, isTrue);
      expect(mushaf.state.currentPage, 50);
    },
  );

  testWidgets('a second playing change mid-animation keeps the selection', (
    tester,
  ) async {
    await pumpPage(tester);

    playing.value = a51;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    playing.value = a51b;
    await tester.pumpAndSettle();

    expect(mushaf.state.currentPage, 51);
    expect(mushaf.state.selectedAyah, a51b);
    expect(mushaf.state.followPlayback, isTrue);
    expect(mushaf.calls.where((c) => c.$2), isEmpty);
  });

  testWidgets('a menu jump calls jumpTo once and no manual setPage', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('foot-menu')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('menu-search')), '120');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('menu-go')));
    await tester.pumpAndSettle();

    expect(mushaf.state.currentPage, 120);
    expect(mushaf.jumps, [120]);
    expect(mushaf.calls.where((c) => c.$2), isEmpty);
  });
}
