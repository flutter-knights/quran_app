import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/page_bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_page_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_page_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/last_read_repository.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../notifications/presentation/alerts_test_harness.dart';

class _FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettings()
    : super(
        SettingsState(
          SettingsModel(
            palette: ColorPalette.neutralLight,
            isFormat12Hours: false,
            isArabic: true,
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _RecordingMushaf extends MushafCubit {
  _RecordingMushaf({
    required super.args,
    required super.currentAyahNotifier,
    required super.pageService,
    required super.getMushafPage,
  });

  final calls = <(int, bool)>[];

  @override
  void setPage(int page, {required bool byUser}) {
    calls.add((page, byUser));
    super.setPage(page, byUser: byUser);
  }
}

class _StubLastReadRepo implements LastReadRepository {
  @override
  Future<LastRead?> get() async => null;
  @override
  Future<void> save(LastRead value) async {}
  @override
  Stream<LastRead?> watch() => const Stream.empty();
}

class _SurahIsPageService implements QuranPageService {
  @override
  int getPageForAyah(int s, int a) => s;
  @override
  AyahIdentifier? getFirstAyahOfPage(int p) => null;
}

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

class _StubPageBookmarkRepo implements PageBookmarkRepository {
  @override
  Future<Either<Failure, Set<int>>> getAll() async => const Right(<int>{});
  @override
  Future<Either<Failure, bool>> toggle(int page) async => const Right(true);
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
    if (sl.isRegistered<QuranPageService>()) sl.unregister<QuranPageService>();
    sl.registerSingleton<QuranPageService>(_SurahIsPageService());
    if (sl.isRegistered<QuranMetaService>()) sl.unregister<QuranMetaService>();
    sl.registerSingleton<QuranMetaService>(
      QuranMetaServiceImpl(pageService: sl<QuranPageService>()),
    );
    if (sl.isRegistered<GetMushafPage>()) sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(_StubMushafRepo()));
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
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: _FakeSettings()),
            BlocProvider<MushafCubit>.value(value: mushaf),
            BlocProvider<PlaybackCubit>.value(value: _FakePlayback()),
            BlocProvider<LastReadCubit>.value(
              value: LastReadCubit(repository: _StubLastReadRepo()),
            ),
            BlocProvider<PageBookmarkCubit>(
              create: (_) => PageBookmarkCubit(
                getPageBookmarks: GetPageBookmarks(_StubPageBookmarkRepo()),
                togglePageBookmark: TogglePageBookmark(_StubPageBookmarkRepo()),
              ),
            ),
          ],
          child: const MushafPage(args: MushafArgs(page: 50)),
        ),
      ),
    );
    await tester.pump();
    playing.value = a50;
    mushaf.toggleSelection(a50);
    await tester.pump();
    mushaf.calls.clear();
  }

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

  testWidgets('a page jump emits exactly one manual setPage', (tester) async {
    await pumpPage(tester);
    mushaf.setChrome(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mushaf-top-page')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '120');
    await tester.tap(find.byKey(const ValueKey('page-jump-go')));
    await tester.pumpAndSettle();

    expect(mushaf.state.currentPage, 120);
    expect(mushaf.calls.where((c) => c.$2), [(120, true)]);
  });
}
