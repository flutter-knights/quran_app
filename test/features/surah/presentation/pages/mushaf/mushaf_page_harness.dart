import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/page_bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_page_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_page_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';
import 'package:quran_app/features/search/data/quran_browse_service_impl.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
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
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';
import 'package:quran_app/generated/l10n.dart';

class FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  FakeSettings({
    MushafReadingMode mode = MushafReadingMode.page,
    bool hintSeen = true,
    bool downloadHintSeen = true,
    bool keepScreenOn = true,
  }) : super(
         SettingsState(
           SettingsModel(
             palette: ColorPalette.neutralLight,
             isFormat12Hours: false,
             isArabic: true,
             readingMode: mode,
             hintSeen: hintSeen,
             downloadHintSeen: downloadHintSeen,
             keepScreenOn: keepScreenOn,
           ),
         ),
       );

  var markHintSeenCalls = 0;
  var markDownloadHintSeenCalls = 0;
  final keepScreenOnSet = <bool>[];

  @override
  void markHintSeen() {
    markHintSeenCalls++;
    emit(SettingsState(state.settingsModel.copyWith(hintSeen: true)));
  }

  @override
  void markDownloadHintSeen() {
    markDownloadHintSeenCalls++;
    emit(SettingsState(state.settingsModel.copyWith(downloadHintSeen: true)));
  }

  @override
  void updateKeepScreenOn(bool value) {
    keepScreenOnSet.add(value);
    emit(SettingsState(state.settingsModel.copyWith(keepScreenOn: value)));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  FakeMushaf(super.initial);

  @override
  int? playingPage;

  final setPages = <(int, bool)>[];
  final jumps = <int>[];
  final selects = <AyahIdentifier>[];
  final toggles = <AyahIdentifier>[];
  var clearCalls = 0;
  var resumeCalls = 0;

  void push(MushafState s) => emit(s);

  @override
  void setPage(int page, {required bool byUser}) {
    setPages.add((page, byUser));
    emit(
      byUser
          ? state.copyWith(
              currentPage: page,
              clearSelected: true,
              clearJumpFrom: true,
            )
          : state.copyWith(currentPage: page),
    );
  }

  @override
  void jumpTo(int page) {
    jumps.add(page);
    if (page == state.currentPage && state.jumpFrom == null) return;
    final origin = state.jumpFrom ?? state.currentPage;
    emit(
      state.copyWith(
        currentPage: page,
        clearSelected: true,
        jumpFrom: page == origin ? null : origin,
        clearJumpFrom: page == origin,
      ),
    );
  }

  @override
  void select(AyahIdentifier ayah) {
    selects.add(ayah);
    if (state.selectedAyah != ayah) emit(state.copyWith(selectedAyah: ayah));
  }

  @override
  void toggleSelection(AyahIdentifier ayah) {
    toggles.add(ayah);
    emit(
      state.selectedAyah == ayah
          ? state.copyWith(clearSelected: true)
          : state.copyWith(selectedAyah: ayah),
    );
  }

  @override
  void clearSelection() {
    clearCalls++;
    if (state.selectedAyah == null) return;
    emit(state.copyWith(clearSelected: true));
  }

  @override
  void resumeFollow() {
    resumeCalls++;
    emit(state.copyWith(followPlayback: true));
  }

  @override
  void setHighlightBounds(double centerY) {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  FakePlayback([super.initial = const PlaybackState()]);

  final playRanges = <(AyahIdentifier, AyahIdentifier)>[];
  var stopCalls = 0;
  var pauseCalls = 0;
  var resumeCalls = 0;

  void push(PlaybackState s) => emit(s);

  @override
  Future<void> playRange({
    required AyahIdentifier start,
    required AyahIdentifier end,
  }) async {
    playRanges.add((start, end));
    emit(
      state.copyWith(
        requestedAyah: start,
        currentAyah: start,
        rangeStart: start,
        rangeEnd: end,
        isPlaying: true,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    emit(state.copyWith(clearCurrentAyah: true, isPlaying: false));
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeBookmarks extends Cubit<BookmarkState> implements BookmarkCubit {
  FakeBookmarks() : super(const BookmarkState(loaded: true));

  final toggles = <AyahIdentifier>[];

  @override
  Future<void> toggle(AyahIdentifier ayah) async => toggles.add(ayah);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeDownloads extends Cubit<SurahDownloadState>
    implements SurahDownloadCubit {
  FakeDownloads() : super(const SurahDownloadState());

  final downloads = <(Reciter, int)>[];
  var cancels = 0;

  @override
  void download(Reciter reciter, int surah) => downloads.add((reciter, surah));

  @override
  Future<void> cancel(Reciter reciter, int surah) async => cancels++;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class StubLastReadRepo implements LastReadRepository {
  StubLastReadRepo([this.stored]);

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

void _replace<T extends Object>(T instance) {
  final sl = GetIt.instance;
  if (sl.isRegistered<T>()) sl.unregister<T>();
  sl.registerSingleton<T>(instance);
}

void setUpMushafHarness({QuranPageService? pageService}) {
  final sl = GetIt.instance;
  _replace<QuranPageService>(pageService ?? _StubPageService());
  _replace<QuranMetaService>(
    QuranMetaServiceImpl(pageService: sl<QuranPageService>()),
  );
  _replace<GetMushafPage>(GetMushafPage(_StubMushafRepo()));
  _replace<QuranBrowseService>(QuranBrowseServiceImpl());
}

typedef MushafHarness = ({
  FakePlayback playback,
  FakeSettings settings,
  FakeBookmarks bookmarks,
  FakeDownloads downloads,
  StubLastReadRepo repo,
});

Future<MushafHarness> pumpMushafPage(
  WidgetTester tester,
  MushafArgs args, {
  required MushafCubit mushaf,
  FakePlayback? playback,
  FakeSettings? settings,
  LastRead? stored,
  bool pushed = false,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = (
    playback: playback ?? FakePlayback(),
    settings: settings ?? FakeSettings(),
    bookmarks: FakeBookmarks(),
    downloads: FakeDownloads(),
    repo: StubLastReadRepo(stored),
  );
  final pageBookmarks = PageBookmarkCubit(
    getPageBookmarks: GetPageBookmarks(_StubPageBookmarkRepo()),
    togglePageBookmark: TogglePageBookmark(_StubPageBookmarkRepo()),
  );
  final lastRead = LastReadCubit(repository: h.repo);
  addTearDown(pageBookmarks.close);
  addTearDown(lastRead.close);

  Widget providers(Widget child) => MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: h.settings),
      BlocProvider<MushafCubit>.value(value: mushaf),
      BlocProvider<PlaybackCubit>.value(value: h.playback),
      BlocProvider<LastReadCubit>.value(value: lastRead),
      BlocProvider<PageBookmarkCubit>.value(value: pageBookmarks),
      BlocProvider<BookmarkCubit>.value(value: h.bookmarks),
      BlocProvider<SurahDownloadCubit>.value(value: h.downloads),
    ],
    child: child,
  );

  MaterialApp app(Widget home) => MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );

  if (pushed) {
    await tester.pumpWidget(providers(app(const SizedBox.shrink())));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => MushafPage(args: args)));
    await tester.pumpAndSettle();
  } else {
    await tester.pumpWidget(app(providers(MushafPage(args: args))));
    await tester.pump();
  }
  return h;
}
