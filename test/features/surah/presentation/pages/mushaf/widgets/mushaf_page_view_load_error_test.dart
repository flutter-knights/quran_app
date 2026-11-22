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
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettings()
    : super(
        SettingsState(
          SettingsModel(
            palette: ColorPalette.neutralLight,
            isFormat12Hours: false,
            isArabic: false,
            readingMode: MushafReadingMode.page,
          ),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf() : super(const MushafState(currentPage: 1));
  int reloads = 0;
  @override
  Future<void> reloadPageAyahs() async => reloads++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FlakyMushafRepo implements MushafRepository {
  int calls = 0;
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
    calls++;
    if (calls == 1) return const Left(CacheFailure('x'));
    return Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
  }
}

class _StubPageBookmarkRepo implements PageBookmarkRepository {
  @override
  Future<Either<Failure, Set<int>>> getAll() async => const Right(<int>{});
  @override
  Future<Either<Failure, bool>> toggle(int page) async => const Right(true);
}

void main() {
  final sl = GetIt.instance;
  late _FlakyMushafRepo repo;
  late _FakeMushaf mushaf;

  setUp(() {
    repo = _FlakyMushafRepo();
    mushaf = _FakeMushaf();
    if (sl.isRegistered<GetMushafPage>()) sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(repo));
  });

  testWidgets('a failed page load shows a retry that reloads', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
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
            BlocProvider<PageBookmarkCubit>(
              create: (_) => PageBookmarkCubit(
                getPageBookmarks: GetPageBookmarks(_StubPageBookmarkRepo()),
                togglePageBookmark: TogglePageBookmark(_StubPageBookmarkRepo()),
              ),
            ),
          ],
          child: const Scaffold(body: MushafPageView(pageNumber: 1)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Couldn\'t load the page'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onLongPressStart != null,
      ),
      findsNothing,
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text('Couldn\'t load the page'), findsNothing);

    await tester.pump();

    expect(find.text('Couldn\'t load the page'), findsNothing);
    expect(repo.calls, 2);
    expect(mushaf.reloads, 1);
  });
}
