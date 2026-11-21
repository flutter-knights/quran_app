import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/page_bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_page_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_page_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
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
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettings()
    : super(
        SettingsState(
          SettingsModel(
            palette: ColorPalette.neutralLight,
            isFormat12Hours: false,
            isArabic: true,
            readingMode: MushafReadingMode.page,
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf(super.initial);
  AyahIdentifier? selected;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  void clearSelection() {}
  @override
  void toggleSelection(AyahIdentifier a) {
    selected = a;
    emit(state.copyWith(selectedAyah: a));
  }

  @override
  void setPage(int p, {required bool byUser}) {}
  @override
  void setHighlightBounds(double centerY) {}
  @override
  void pinOverlay() {}
  @override
  void unpinOverlay() {}
  @override
  void toggleChrome() {}
  @override
  void setChrome(bool visible) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier =>
      throw UnimplementedError();
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback(super.initial);
  int stopCalls = 0;
  @override
  Future<void> stop() async {
    stopCalls++;
    emit(state.copyWith(clearCurrentAyah: true, isPlaying: false));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubLastReadRepo implements LastReadRepository {
  LastRead? saved;
  @override
  Future<LastRead?> get() async => null;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Stream<LastRead?> watch() => const Stream.empty();
}

class _StubPageService implements QuranPageService {
  @override
  int getPageForAyah(int s, int a) => 1;
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

  setUp(() {
    if (sl.isRegistered<QuranPageService>()) sl.unregister<QuranPageService>();
    sl.registerSingleton<QuranPageService>(_StubPageService());
    if (sl.isRegistered<QuranMetaService>()) sl.unregister<QuranMetaService>();
    sl.registerSingleton<QuranMetaService>(
      QuranMetaServiceImpl(pageService: sl<QuranPageService>()),
    );
    if (sl.isRegistered<GetMushafPage>()) sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(_StubMushafRepo()));
  });

  Future<(_StubLastReadRepo, _FakePlayback)> disposeOn(
    WidgetTester tester,
    MushafArgs args, {
    Future<void> Function()? act,
    MushafState? mushafState,
    PlaybackState playbackState = const PlaybackState(),
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mushaf = _FakeMushaf(
      mushafState ??
          const MushafState(
            currentPage: 7,
            selectedAyah: AyahIdentifier(surah: 2, ayah: 5),
            chromeVisible: true,
          ),
    );
    final playback = _FakePlayback(playbackState);
    final repo = _StubLastReadRepo();

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
            BlocProvider<PlaybackCubit>.value(value: playback),
            BlocProvider<LastReadCubit>.value(
              value: LastReadCubit(repository: repo),
            ),
            BlocProvider<PageBookmarkCubit>(
              create: (_) => PageBookmarkCubit(
                getPageBookmarks: GetPageBookmarks(_StubPageBookmarkRepo()),
                togglePageBookmark: TogglePageBookmark(_StubPageBookmarkRepo()),
              ),
            ),
          ],
          child: MushafPage(args: args),
        ),
      ),
    );
    await act?.call();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    return (repo, playback);
  }

  testWidgets('on dispose: saves (page, selected) then stops playback', (
    tester,
  ) async {
    final (repo, playback) = await disposeOn(tester, const MushafArgs(page: 7));

    final saved = repo.saved!;
    expect(saved.page, 7);
    expect(saved.ayah, const AyahIdentifier(surah: 2, ayah: 5));
    expect(saved.updatedAt, isNotNull);
    expect(playback.stopCalls, 1);
  });

  testWidgets('jump arrival: dispose does not overwrite last read', (
    tester,
  ) async {
    final (repo, playback) = await disposeOn(
      tester,
      const MushafArgs(page: 7, origin: MushafOrigin.jump),
    );

    expect(repo.saved, isNull);
    expect(playback.stopCalls, 1);
  });

  testWidgets('jump arrival: a manual page swipe lifts the guard', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7, origin: MushafOrigin.jump),
      act: () async {
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      },
    );

    expect(repo.saved, isNotNull);
  });

  testWidgets('in-place jump: dispose does not overwrite last read', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      act: () async {
        await tester.tap(find.byKey(const ValueKey('mushaf-top-page')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '300');
        await tester.tap(find.byKey(const ValueKey('page-jump-go')));
        await tester.pumpAndSettle();
      },
    );

    expect(repo.saved, isNull);
  });

  group('browse bar', () {
    double browseBarOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(MushafBrowseBar),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('hides while a recitation is active', (tester) async {
      await disposeOn(
        tester,
        const MushafArgs(page: 7),
        mushafState: const MushafState(currentPage: 7, chromeVisible: true),
        playbackState: const PlaybackState(
          requestedAyah: AyahIdentifier(surah: 2, ayah: 5),
          isLoading: true,
        ),
        act: () async {
          await tester.pump();
          expect(browseBarOpacity(tester), 0);
        },
      );
    });

    testWidgets('shows when nothing is playing', (tester) async {
      await disposeOn(
        tester,
        const MushafArgs(page: 7),
        mushafState: const MushafState(currentPage: 7, chromeVisible: true),
        act: () async {
          await tester.pumpAndSettle();
          expect(browseBarOpacity(tester), 1);
        },
      );
    });
  });
}
