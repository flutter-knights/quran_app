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
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettings({MushafReadingMode mode = MushafReadingMode.page})
    : super(
        SettingsState(
          SettingsModel(
            palette: ColorPalette.neutralLight,
            isFormat12Hours: false,
            isArabic: true,
            readingMode: mode,
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
  int? playingPage;
  void push(MushafState s) => emit(s);
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
  void setPage(int p, {required bool byUser}) =>
      emit(state.copyWith(currentPage: p));
  @override
  void setHighlightBounds(double centerY) {}
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
  _StubLastReadRepo([this.stored]);
  final LastRead? stored;
  LastRead? saved;
  @override
  Future<LastRead?> get() async => stored;
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
    Future<void> Function(_FakeMushaf mushaf)? act,
    MushafState? mushafState,
    PlaybackState playbackState = const PlaybackState(),
    LastRead? stored,
    MushafReadingMode mode = MushafReadingMode.page,
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
    final repo = _StubLastReadRepo(stored);

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
            BlocProvider<SettingsCubit>.value(value: _FakeSettings(mode: mode)),
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
    await act?.call(mushaf);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    return (repo, playback);
  }

  testWidgets(
    'on dispose: saves (page, selected) and the recitation keeps playing',
    (tester) async {
      final (repo, playback) = await disposeOn(
        tester,
        const MushafArgs(page: 7),
        playbackState: const PlaybackState(
          currentAyah: AyahIdentifier(surah: 2, ayah: 5),
          isPlaying: true,
        ),
      );

      final saved = repo.saved!;
      expect(saved.page, 7);
      expect(saved.ayah, const AyahIdentifier(surah: 2, ayah: 5));
      expect(saved.updatedAt, isNotNull);
      expect(playback.stopCalls, 0);
      expect(
        playback.state.currentAyah,
        const AyahIdentifier(surah: 2, ayah: 5),
      );
    },
  );

  testWidgets('jump arrival: dispose does not overwrite last read', (
    tester,
  ) async {
    final (repo, playback) = await disposeOn(
      tester,
      const MushafArgs(page: 7, origin: MushafOrigin.jump),
    );

    expect(repo.saved, isNull);
    expect(playback.stopCalls, 0);
  });

  testWidgets('jump arrival: a manual page swipe lifts the guard', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7, origin: MushafOrigin.jump),
      act: (_) async {
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
      act: (_) async {
        await tester.tap(find.byKey(const ValueKey('mushaf-top-page')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '300');
        await tester.tap(find.byKey(const ValueKey('page-jump-go')));
        await tester.pumpAndSettle();
      },
    );

    expect(repo.saved, isNull);
  });

  testWidgets('a normal arrival on the last-read page keeps its ayah', (
    tester,
  ) async {
    const stored = LastRead(page: 7, ayah: AyahIdentifier(surah: 3, ayah: 5));
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      mushafState: const MushafState(currentPage: 7, chromeVisible: true),
      stored: stored,
      act: (_) => tester.pumpAndSettle(),
    );

    expect(repo.saved!.page, 7);
    expect(repo.saved!.ayah, stored.ayah);
  });

  testWidgets('a stored ayah from another page is not carried over', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      mushafState: const MushafState(currentPage: 7, chromeVisible: true),
      stored: const LastRead(page: 50, ayah: AyahIdentifier(surah: 3, ayah: 5)),
      act: (_) => tester.pumpAndSettle(),
    );

    expect(repo.saved!.page, 7);
    expect(repo.saved!.ayah, isNull);
  });

  testWidgets('an in-place jump saves the pre-jump page, not the target', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      mushafState: const MushafState(currentPage: 7, chromeVisible: true),
      mode: MushafReadingMode.scroll,
      act: (mushaf) async {
        await tester.pumpAndSettle();
        mushaf.push(mushaf.state.copyWith(currentPage: 9));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const ValueKey('mushaf-top-page')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '300');
        await tester.tap(find.byKey(const ValueKey('page-jump-go')));
        await tester.pumpAndSettle();
        expect(mushaf.state.currentPage, 300);
      },
    );

    expect(repo.saved!.page, 9);
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
        act: (_) async {
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
        act: (_) async {
          await tester.pumpAndSettle();
          expect(browseBarOpacity(tester), 1);
        },
      );
    });
  });
}
