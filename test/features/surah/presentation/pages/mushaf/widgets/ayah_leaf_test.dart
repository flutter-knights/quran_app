import 'dart:ui' show SemanticsFlags, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../bookmarks/place_fakes.dart';
import '../../../../../tafsir/tafsir_fakes.dart';

class _Calls {
  final taps = <String>[];
  VoidCallback tap(String name) =>
      () => taps.add(name);
}

Widget _host(
  SavedAyatCubit cubit,
  TafsirCubit tafsir,
  AyahIdentifier ayah,
  _Calls calls, {
  double scale = 1,
  bool tafsirLead = true,
}) => MaterialApp(
  localizationsDelegates: const [
    S.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: S.delegate.supportedLocales,
  locale: const Locale('ar'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: MultiBlocProvider(
      providers: [
        BlocProvider<SavedAyatCubit>.value(value: cubit),
        BlocProvider<TafsirCubit>.value(value: tafsir),
      ],
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 360,
          child: AyahLeaf(
            ayah: ayah,
            colors: MushafPaper.cream.colors,
            onClose: calls.tap('close'),
            onListenFromHere: calls.tap('here'),
            onListenFromSurahStart: calls.tap('start'),
            onListenPage: calls.tap('page'),
            onFasil: calls.tap('fasil'),
            onExpand: calls.tap('expand'),
            tafsirLead: tafsirLead,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late FakeSavedAyatCubit cubit;
  late FakeTafsirCubit tafsir;
  late _Calls calls;

  const ayah = AyahIdentifier(surah: 3, ayah: 7);

  setUp(() async {
    cubit = FakeSavedAyatCubit();
    tafsir = FakeTafsirCubit();
    calls = _Calls();
    addTearDown(cubit.close);
    addTearDown(tafsir.close);
    await tafsir.load(ayah);
  });

  testWidgets('ayah leaf labels are distinct', (tester) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    final labels = [
      for (final key in [
        'leaf-listen',
        'leaf-tafsir',
        'leaf-fasil',
        'leaf-save',
      ])
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Text),
              ),
            )
            .data,
    ];
    expect(labels, ['استماع من هنا', 'تفسير الآية', 'فاصل', 'حفظ الآية']);
    expect(labels.toSet().length, 4);
    expect(find.byKey(const ValueKey('leaf-share')), findsNothing);
  });

  testWidgets('title names the surah and ayah in Arabic-Indic digits', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    expect(find.text('آل عمران، الآية ٧'), findsOneWidget);
  });

  testWidgets('listen from here, close, فاصل and save reach their handlers', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-listen')));
    await tester.tap(find.byKey(const ValueKey('leaf-close')));
    await tester.tap(find.byKey(const ValueKey('leaf-tafsir')));
    await tester.tap(find.byKey(const ValueKey('leaf-fasil')));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pump();
    expect(calls.taps, ['here', 'close', 'expand', 'fasil']);
    expect(cubit.saves.last, ayah);
  });

  testWidgets('saving confirms and تراجع removes it', (tester) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('حُفظت الآية ٧ من آل عمران'), findsOneWidget);

    await tester.tap(find.text('تراجع'));
    await tester.pump();

    expect(cubit.removes.last.ayah, ayah);
  });

  testWidgets('the save notice leaves by itself', (tester) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a saved ayah is removed with undo', (tester) async {
    final place = savedPlace(ayah);
    final saved = FakeSavedAyatCubit(
      SavedAyatState(items: [place], loaded: true),
    );
    addTearDown(saved.close);
    await tester.pumpWidget(_host(saved, tafsir, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(saved.removes.last, place);
    expect(find.text('أُزيلت الآية ٧ من آل عمران'), findsOneWidget);

    await tester.tap(find.text('تراجع'));
    await tester.pump();

    expect(saved.restores.last, place);
  });

  testWidgets('a failed removal shows the error, not a removed notice', (
    tester,
  ) async {
    final place = savedPlace(ayah);
    final saved = FakeSavedAyatCubit(
      SavedAyatState(items: [place], loaded: true),
    )..failRemove = true;
    addTearDown(saved.close);
    await tester.pumpWidget(_host(saved, tafsir, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(saved.removes.last, place);
    expect(find.text('تعذّر الحفظ، حاول مرة أخرى'), findsOneWidget);
    expect(find.text('أُزيلت الآية ٧ من آل عمران'), findsNothing);
    expect(saved.state.contains(ayah), isTrue);
  });

  testWidgets('a save the cubit refuses without a failure shows nothing', (
    tester,
  ) async {
    final saved = FakeSavedAyatCubit()..refuseSave = true;
    addTearDown(saved.close);
    await tester.pumpWidget(_host(saved, tafsir, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(saved.saves.last, ayah);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed save shows the error', (tester) async {
    final saved = FakeSavedAyatCubit()..failSave = true;
    addTearDown(saved.close);
    await tester.pumpWidget(_host(saved, tafsir, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(saved.saves.last, ayah);
    expect(find.text('تعذّر الحفظ، حاول مرة أخرى'), findsOneWidget);
    expect(find.text('حُفظت الآية ٧ من آل عمران'), findsNothing);
  });

  testWidgets('dragging down closes', (tester) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    await tester.fling(find.byType(AyahLeaf), const Offset(0, 300), 1000);
    expect(calls.taps, ['close']);
  });

  testWidgets('a sajda ayah carries the badge', (tester) async {
    await tester.pumpWidget(
      _host(cubit, tafsir, const AyahIdentifier(surah: 32, ayah: 15), calls),
    );
    expect(find.text('سجدة'), findsOneWidget);
    await tester.pumpWidget(
      _host(cubit, tafsir, const AyahIdentifier(surah: 32, ayah: 14), calls),
    );
    expect(find.text('سجدة'), findsNothing);
  });

  testWidgets('the banner variant offers the surah actions only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(cubit, tafsir, const AyahIdentifier(surah: 5, ayah: 0), calls),
    );
    expect(find.text('سورة المائدة'), findsOneWidget);
    expect(find.text('مدنية، ١٢٠ آية'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leaf-surah-start')));
    await tester.tap(find.byKey(const ValueKey('leaf-page')));
    expect(calls.taps, ['start', 'page']);
    expect(find.text('استماع من بداية السورة'), findsOneWidget);
    expect(find.text('استماع الصفحة كاملة'), findsOneWidget);
    expect(find.text('مشاركة'), findsNothing);
    expect(find.byKey(const ValueKey('leaf-tafsir')), findsNothing);
    expect(find.byKey(const ValueKey('tafsir-lead')), findsNothing);
    await tester.fling(find.byType(AyahLeaf), const Offset(0, -300), 1000);
    expect(calls.taps, ['start', 'page']);
    expect(find.text('حفظ الآية'), findsNothing);
    expect(find.text('فاصل'), findsNothing);
    expect(find.textContaining('الآية ٠'), findsNothing);
  });

  testWidgets('the save action announces whether the ayah is saved', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    SemanticsFlags saveFlags() => tester
        .getSemantics(find.byKey(const ValueKey('leaf-save')))
        .getSemanticsData()
        .flagsCollection;

    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    expect(saveFlags().isButton, isTrue);
    expect(saveFlags().isToggled, Tristate.isFalse);
    final saved = FakeSavedAyatCubit(
      SavedAyatState(items: [savedPlace(ayah)], loaded: true),
    );
    addTearDown(saved.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(saved, tafsir, ayah, calls));
    expect(saveFlags().isToggled, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('fits at 2x text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls, scale: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tafsir line shows one line and opens the full detent', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    final lead = find.byKey(const ValueKey('tafsir-lead'));
    final text = tester.widget<Text>(
      find.descendant(of: lead, matching: find.text(tafsirText)),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    await tester.tap(lead);
    expect(calls.taps, ['expand']);
  });

  testWidgets('tafsirLead false hides the line', (tester) async {
    await tester.pumpWidget(
      _host(cubit, tafsir, ayah, calls, tafsirLead: false),
    );
    expect(find.byKey(const ValueKey('tafsir-lead')), findsNothing);
  });

  testWidgets('dragging up opens the full detent', (tester) async {
    await tester.pumpWidget(_host(cubit, tafsir, ayah, calls));
    await tester.fling(find.byType(AyahLeaf), const Offset(0, -300), 1000);
    expect(calls.taps, ['expand']);
  });
}
