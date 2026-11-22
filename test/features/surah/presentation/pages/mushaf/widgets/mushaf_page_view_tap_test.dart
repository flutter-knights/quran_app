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
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';
import 'package:quran_app/generated/l10n.dart';

const _ayah = AyahIdentifier(surah: 2, ayah: 6);

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
  _FakeMushaf() : super(const MushafState(currentPage: 3));
  final toggled = <AyahIdentifier>[];
  final selected = <AyahIdentifier>[];
  int cleared = 0;
  @override
  void toggleSelection(AyahIdentifier ayah) => toggled.add(ayah);
  @override
  void select(AyahIdentifier ayah) => selected.add(ayah);
  @override
  void clearSelection() => cleared++;
  @override
  void setHighlightBounds(double centerY) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      const Right(
        MushafPageEntity(
          pageNumber: 3,
          ayahs: [
            AyahBoundEntity(
              ayah: _ayah,
              lines: [NormalizedRect(x: 0.1, y: 0.1, w: 0.8, h: 0.05)],
            ),
          ],
        ),
      );
}

class _StubPageBookmarkRepo implements PageBookmarkRepository {
  @override
  Future<Either<Failure, Set<int>>> getAll() async => const Right(<int>{});
  @override
  Future<Either<Failure, bool>> toggle(int page) async => const Right(true);
}

void main() {
  final sl = GetIt.instance;
  late _FakeMushaf mushaf;

  setUp(() {
    mushaf = _FakeMushaf();
    if (sl.isRegistered<GetMushafPage>()) sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(_StubMushafRepo()));
  });

  Future<void> pumpView(WidgetTester tester) async {
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
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: MushafPageView(pageNumber: 3),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Offset at(WidgetTester tester, double nx, double ny) {
    final rect = tester.getRect(find.byType(AspectRatio));
    return rect.topLeft + Offset(rect.width * nx, rect.height * ny);
  }

  testWidgets('a tap on an ayah toggles it', (tester) async {
    await pumpView(tester);

    await tester.tapAt(at(tester, 0.5, 0.125));

    expect(mushaf.toggled, [_ayah]);
    expect(mushaf.cleared, 0);
  });

  testWidgets('a tap on blank paper clears the selection', (tester) async {
    await pumpView(tester);

    await tester.tapAt(at(tester, 0.5, 0.9));

    expect(mushaf.cleared, 1);
    expect(mushaf.toggled, isEmpty);
  });

  testWidgets('a long-press selects', (tester) async {
    await pumpView(tester);

    await tester.longPressAt(at(tester, 0.5, 0.125));

    expect(mushaf.selected, [_ayah]);
    expect(mushaf.toggled, isEmpty);
  });

  testWidgets('the page keeps the image aspect', (tester) async {
    await pumpView(tester);

    final box = tester.widget<AspectRatio>(find.byType(AspectRatio));
    final size = tester.getSize(find.byType(AspectRatio));

    expect(box.aspectRatio, mushafPageAspect);
    expect(size.width / size.height, closeTo(mushafPageAspect, 0.001));
  });
}
