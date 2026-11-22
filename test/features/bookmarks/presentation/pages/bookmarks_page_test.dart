import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/bookmarks_page.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../surah/presentation/pages/mushaf/mushaf_page_harness.dart';
import '../../place_fakes.dart';

const _fatiha = AyahIdentifier(surah: 2, ayah: 5);

class _FakeHadithBookmarks extends Cubit<HadithBookmarkState>
    implements HadithBookmarkCubit {
  _FakeHadithBookmarks(super.initial);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Object? captured;

  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  tearDown(() async {
    if (sl.isRegistered<HadithBookmarkCubit>()) {
      await sl.unregister<HadithBookmarkCubit>();
    }
  });

  Future<void> open(
    WidgetTester tester, {
    Set<HadithBookmark> hadiths = const {},
  }) async {
    captured = null;
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hadithCubit = _FakeHadithBookmarks(
      HadithBookmarkState(bookmarks: hadiths, loaded: true),
    );
    sl.registerSingleton<HadithBookmarkCubit>(hadithCubit);
    final fawasil = FakeFasilCubit(const FasilState(loaded: true));
    final saved = FakeSavedAyatCubit(
      SavedAyatState(loaded: true, items: [savedPlace(_fatiha)]),
    );
    final settings = FakeSettings();
    final last = LastReadCubit(
      repository: StubLastReadRepo(const LastRead(page: 50)),
    );
    addTearDown(hadithCubit.close);
    addTearDown(fawasil.close);
    addTearDown(saved.close);
    addTearDown(settings.close);
    addTearDown(last.close);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const BookmarksPage()),
        GoRoute(
          path: AppRouter.mushafPath,
          builder: (context, state) {
            captured = state.extra;
            return const Scaffold(body: Text('reader'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FasilCubit>.value(value: fawasil),
          BlocProvider<SavedAyatCubit>.value(value: saved),
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<LastReadCubit>.value(value: last),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  testWidgets(
    'the page is أماكني with the Quran groups and the hadith section',
    (tester) async {
      await open(
        tester,
        hadiths: {const HadithBookmark(bookSlug: 'bukhari', hadithNumber: '1')},
      );

      expect(find.text('أماكني'), findsOneWidget);
      expect(key('places-continue'), findsOneWidget);
      expect(key('places-fasil-wird'), findsOneWidget);
      expect(find.text('الآيات المحفوظة'), findsOneWidget);
      expect(find.text('الأحاديث'), findsOneWidget);
      expect(find.text('الصفحات'), findsNothing);
    },
  );

  testWidgets('the hadith section is absent without hadith bookmarks', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('الأحاديث'), findsNothing);
  });

  testWidgets('a saved ayah opens the reader focused on it', (tester) async {
    await open(tester);

    await tester.tap(key('places-saved-2:5'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final args = captured as MushafArgs;
    expect(args.focusAyah, _fatiha);
    expect(args.origin, MushafOrigin.jump);
  });

  testWidgets('continue opens the reader at the page', (tester) async {
    await open(tester);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    expect(captured, 50);
  });
}
