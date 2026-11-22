import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/surah_download_button.dart';
import 'package:quran_app/features/search/data/quran_browse_service_impl.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/menu_sheet.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState(reciter: Reciter.husary));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDownloads extends Cubit<SurahDownloadState>
    implements SurahDownloadCubit {
  _FakeDownloads() : super(const SurahDownloadState());

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  MenuAction? result;
  var closed = false;

  setUp(() {
    result = null;
    closed = false;
  });

  Future<void> open(
    WidgetTester tester, {
    int currentPage = 50,
    int? currentSurah = 3,
    int currentJuz = 4,
    bool viaShow = false,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final playback = _FakePlayback();
    final downloads = _FakeDownloads();
    addTearDown(playback.close);
    addTearDown(downloads.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<PlaybackCubit>.value(value: playback),
          BlocProvider<SurahDownloadCubit>.value(value: downloads),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = viaShow
                      ? await MenuSheet.show(
                          context,
                          currentPage: currentPage,
                          currentSurah: currentSurah,
                          currentJuz: currentJuz,
                        )
                      : await showModalBottomSheet<MenuAction>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => MenuSheet(
                            currentPage: currentPage,
                            currentSurah: currentSurah,
                            currentJuz: currentJuz,
                            juzEntries: QuranBrowseServiceImpl().juzEntries(),
                          ),
                        );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(
    WidgetTester tester,
    String key, {
    double delta = 200,
  }) async {
    final item = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      item,
      delta,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('menu-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
  }

  for (final (key, action) in <(String, MenuAction)>[
    ('menu-tile-places', const MenuOpenPlaces()),
    ('menu-tile-display', const MenuOpenDisplay()),
    ('menu-tile-play', const MenuPlayPage()),
  ]) {
    testWidgets('$key pops its action', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(result, action);
    });
  }

  testWidgets('typing ٥٨٢ shows the result row and jumps', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('menu-search')), '٥٨٢');
    await tester.pump();
    expect(find.text('صفحة ٥٨٢، النبأ، الجزء ٣٠'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-go')));
    await tester.pumpAndSettle();
    expect(result, const MenuJump(582));
  });

  testWidgets('an out-of-range number shows the inline error', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('menu-search')), '٦٠٥');
    await tester.pump();
    expect(find.text('اكتب رقمًا من ١ إلى ٦٠٤'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-go')), findsNothing);
  });

  testWidgets('the search field accepts both digit sets', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('menu-search')), '٥8٢');
    await tester.pump();
    expect(find.text('٥8٢'), findsOneWidget);
    expect(find.text('صفحة ٥٨٢، النبأ، الجزء ٣٠'), findsOneWidget);
  });

  testWidgets('surah rows mark the current surah and carry a download button', (
    tester,
  ) async {
    await open(tester);
    final row = find.byKey(const ValueKey('menu-surah-3'));
    for (final text in ['أنت هنا', 'مدنية، ٢٠٠ آية', 'صفحة ٥٠']) {
      expect(
        find.descendant(of: row, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    expect(
      find.descendant(of: row, matching: find.byType(SurahDownloadButton)),
      findsOneWidget,
    );
    await scrollTo(tester, 'menu-surah-18');
    await tester.tap(find.byKey(const ValueKey('menu-surah-18')));
    await tester.pumpAndSettle();
    expect(result, const MenuJump(293));
  });

  testWidgets('the juz tab marks the current juz', (tester) async {
    await open(tester, currentJuz: 30);
    await tester.tap(find.text('الأجزاء'));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'menu-juz-30');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('menu-juz-30')),
        matching: find.text('أنت هنا'),
      ),
      findsOneWidget,
    );
    await scrollTo(tester, 'menu-juz-2', delta: -200);
    await tester.tap(find.byKey(const ValueKey('menu-juz-2')));
    await tester.pumpAndSettle();
    expect(result, const MenuJump(22));
  });

  testWidgets('the sheet opens tall', (tester) async {
    if (!sl.isRegistered<QuranBrowseService>()) {
      sl.registerLazySingleton<QuranBrowseService>(QuranBrowseServiceImpl.new);
      addTearDown(() => sl.unregister<QuranBrowseService>());
    }
    await open(tester, viaShow: true);
    expect(tester.getSize(find.byType(MenuSheet)).height, 0.85 * 800);
    expect(closed, isFalse);
  });

  testWidgets('every surah row is at least 56 high', (tester) async {
    await open(tester);
    for (final n in [1, 2, 3]) {
      expect(
        tester.getSize(find.byKey(ValueKey('menu-surah-$n'))).height,
        greaterThanOrEqualTo(56),
        reason: 'surah $n',
      );
    }
  });
}
