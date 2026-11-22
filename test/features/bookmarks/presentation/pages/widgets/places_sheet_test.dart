import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/places_sheet.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../surah/presentation/pages/mushaf/mushaf_page_harness.dart';
import '../../../place_fakes.dart';

const _hifz = AyahIdentifier(surah: 3, ayah: 6);
const _fatiha = AyahIdentifier(surah: 2, ayah: 5);
const _imran = AyahIdentifier(surah: 3, ayah: 7);

void main() {
  PlacesOpen? result;
  late FakeFasilCubit fawasil;
  late FakeSavedAyatCubit saved;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  setUp(() => result = null);

  Future<void> open(
    WidgetTester tester, {
    LastRead? lastRead,
    FasilState fasil = const FasilState(loaded: true),
    SavedAyatState savedAyat = const SavedAyatState(loaded: true),
    double textScale = 1,
    String locale = 'ar',
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fawasil = FakeFasilCubit(fasil);
    saved = FakeSavedAyatCubit(savedAyat);
    final settings = FakeSettings();
    final last = LastReadCubit(repository: StubLastReadRepo(lastRead));
    addTearDown(fawasil.close);
    addTearDown(saved.close);
    addTearDown(settings.close);
    addTearDown(last.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FasilCubit>.value(value: fawasil),
          BlocProvider<SavedAyatCubit>.value(value: saved),
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<LastReadCubit>.value(value: last),
        ],
        child: MaterialApp(
          locale: Locale(locale),
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await PlacesSheet.show(
                    context,
                    now: () => DateTime(2026, 11, 21, 12),
                  );
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

  Finder key(String value) => find.byKey(ValueKey(value));

  final stored = LastRead(
    page: 50,
    ayah: _imran,
    updatedAt: DateTime(2026, 11, 21, 6, 10),
  );

  testWidgets('continue card names the place and the time', (tester) async {
    await open(tester, lastRead: stored);

    expect(find.text('متابعة القراءة'), findsOneWidget);
    expect(find.text('آل عمران ٧، صفحة ٥٠'), findsOneWidget);
    expect(find.text('اليوم ٦:١٠ ص'), findsOneWidget);
    expect(
      find.text('تُحفظ وحدها حيث تقرأ، ولا تغيّرها الانتقالات'),
      findsOneWidget,
    );

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    expect(result, const PlacesOpen(page: 50));
  });

  testWidgets('continue card hides the time without updatedAt', (tester) async {
    await open(tester, lastRead: const LastRead(page: 50, ayah: _imran));

    expect(find.text('آل عمران ٧، صفحة ٥٠'), findsOneWidget);
    expect(find.textContaining('اليوم'), findsNothing);
  });

  testWidgets('continue card is absent without a last read', (tester) async {
    await open(tester);

    expect(key('places-continue'), findsNothing);
  });

  testWidgets('continue card without an ayah names only the page', (
    tester,
  ) async {
    await open(tester, lastRead: const LastRead(page: 50));

    expect(find.text('صفحة ٥٠'), findsOneWidget);
    expect(find.textContaining('آل عمران'), findsNothing);
  });

  testWidgets('three فاصل rows; placed ones go and rename', (tester) async {
    await open(
      tester,
      fasil: FasilState(
        loaded: true,
        slots: {
          FasilSlot.hifz: fasilPlace(
            FasilSlot.hifz,
            _hifz,
            at: DateTime(2026, 11, 20, 21, 40),
          ),
        },
      ),
    );

    expect(key('places-fasil-wird'), findsOneWidget);
    expect(key('places-fasil-hifz'), findsOneWidget);
    expect(key('places-fasil-muraja'), findsOneWidget);
    expect(find.text('الحفظ'), findsOneWidget);
    expect(find.text('آل عمران ٦، صفحة ٥٠'), findsOneWidget);
    expect(find.text('نُقل أمس ٩:٤٠ م'), findsOneWidget);
    expect(find.text('غير موضوع'), findsNWidgets(2));
    expect(key('places-go-wird'), findsNothing);
    expect(key('places-rename-wird'), findsNothing);
    expect(key('places-rename-hifz'), findsOneWidget);

    await tester.tap(key('places-go-hifz'));
    await tester.pumpAndSettle();

    expect(result, const PlacesOpen(page: 50, focus: _hifz));
  });

  testWidgets('rename passes the typed name to the cubit', (tester) async {
    await open(
      tester,
      fasil: FasilState(
        loaded: true,
        slots: {FasilSlot.hifz: fasilPlace(FasilSlot.hifz, _hifz)},
      ),
    );

    await tester.tap(key('places-rename-hifz'));
    await tester.pumpAndSettle();
    expect(find.text('تسمية الفاصل'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'الحفظ',
    );

    await tester.enterText(find.byType(TextField), 'حفظ رمضان');
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();

    expect(fawasil.renames.last, (FasilSlot.hifz, 'حفظ رمضان'));
  });

  testWidgets('cancelling the rename writes nothing', (tester) async {
    await open(
      tester,
      fasil: FasilState(
        loaded: true,
        slots: {FasilSlot.hifz: fasilPlace(FasilSlot.hifz, _hifz)},
      ),
    );

    await tester.tap(key('places-rename-hifz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(fawasil.renames, isEmpty);
  });

  testWidgets('saved ayat show the count, the date unless migrated, and open '
      'with focus', (tester) async {
    await open(
      tester,
      savedAyat: SavedAyatState(
        loaded: true,
        items: [savedPlace(_fatiha), savedPlace(_imran, migrated: true)],
      ),
    );

    expect(find.text('الآيات المحفوظة'), findsOneWidget);
    expect(find.text('٢'), findsOneWidget);
    expect(find.text('البقرة ٥'), findsOneWidget);
    expect(find.text('آل عمران ٧'), findsOneWidget);
    expect(find.text('حُفظت ١٤ نوفمبر'), findsOneWidget);

    await tester.tap(key('places-saved-3:7'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(result, const PlacesOpen(page: 50, focus: _imran));
  });

  testWidgets('removing from the row menu offers undo', (tester) async {
    final place = savedPlace(_fatiha);
    await open(tester, savedAyat: SavedAyatState(loaded: true, items: [place]));

    await tester.tap(
      find.descendant(
        of: key('places-saved-2:5'),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(key('place-remove'));
    await tester.pumpAndSettle();

    expect(saved.removes.last, place);
    expect(find.text('أُزيلت الآية ٥ من البقرة'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(SnackBar),
        matching: find.byType(BottomSheet),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();

    expect(saved.restores.last, place);
  });

  testWidgets('no saved ayat shows the empty line', (tester) async {
    await open(tester);

    expect(find.text('لا توجد آيات محفوظة بعد'), findsOneWidget);
  });

  testWidgets('the sheet is titled أماكني and closes', (tester) async {
    await open(tester);

    expect(find.text('أماكني'), findsOneWidget);

    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();

    expect(find.text('أماكني'), findsNothing);
    expect(result, isNull);
  });

  for (final (locale, icon) in [
    ('ar', HugeIcons.strokeRoundedArrowLeft02),
    ('en', HugeIcons.strokeRoundedArrowRight02),
  ]) {
    testWidgets('the row arrow follows the reading direction in $locale', (
      tester,
    ) async {
      await open(
        tester,
        locale: locale,
        savedAyat: SavedAyatState(loaded: true, items: [savedPlace(_fatiha)]),
      );

      final icons = tester.widgetList<HugeIcon>(
        find.descendant(
          of: key('places-saved-2:5'),
          matching: find.byType(HugeIcon),
        ),
      );

      expect(icons.any((i) => identical(i.icon, icon)), isTrue);
    });
  }

  testWidgets('fits at 2x text', (tester) async {
    await open(
      tester,
      textScale: 2,
      lastRead: stored,
      fasil: FasilState(
        loaded: true,
        slots: {
          for (final slot in FasilSlot.values)
            slot: fasilPlace(slot, _hifz, name: 'اسم طويل جدا للفاصل'),
        },
      ),
      savedAyat: SavedAyatState(
        loaded: true,
        items: [savedPlace(_fatiha), savedPlace(_imran)],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
