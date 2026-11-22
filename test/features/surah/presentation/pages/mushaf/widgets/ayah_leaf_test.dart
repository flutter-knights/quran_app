import 'dart:ui' show SemanticsFlags, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../bookmarks/place_fakes.dart';

class _Calls {
  final taps = <String>[];
  VoidCallback tap(String name) =>
      () => taps.add(name);
}

Widget _host(
  SavedAyatCubit cubit,
  AyahIdentifier ayah,
  _Calls calls, {
  double scale = 1,
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
    body: BlocProvider<SavedAyatCubit>.value(
      value: cubit,
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
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late FakeSavedAyatCubit cubit;
  late _Calls calls;

  setUp(() {
    cubit = FakeSavedAyatCubit();
    calls = _Calls();
    addTearDown(cubit.close);
  });

  const ayah = AyahIdentifier(surah: 3, ayah: 7);

  testWidgets('ayah leaf labels are distinct', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    final labels = [
      for (final key in [
        'leaf-listen',
        'leaf-fasil',
        'leaf-save',
        'leaf-share',
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
    expect(labels, ['استماع من هنا', 'فاصل', 'حفظ الآية', 'مشاركة']);
    expect(labels.toSet().length, 4);
  });

  testWidgets('title names the surah and ayah in Arabic-Indic digits', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    expect(find.text('آل عمران، الآية ٧'), findsOneWidget);
  });

  testWidgets('listen from here, close, فاصل and save reach their handlers', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-listen')));
    await tester.tap(find.byKey(const ValueKey('leaf-close')));
    await tester.tap(find.byKey(const ValueKey('leaf-fasil')));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pump();
    expect(calls.taps, ['here', 'close', 'fasil']);
    expect(cubit.saves.last, ayah);
  });

  testWidgets('saving confirms and تراجع removes it', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('حُفظت الآية ٧ من آل عمران'), findsOneWidget);

    await tester.tap(find.text('تراجع'));
    await tester.pump();

    expect(cubit.removes.last.ayah, ayah);
  });

  testWidgets('the save notice leaves by itself', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
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
    await tester.pumpWidget(_host(saved, ayah, calls));
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
    await tester.pumpWidget(_host(saved, ayah, calls));
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
    await tester.pumpWidget(_host(saved, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(saved.saves.last, ayah);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed save shows the error', (tester) async {
    final saved = FakeSavedAyatCubit()..failSave = true;
    addTearDown(saved.close);
    await tester.pumpWidget(_host(saved, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(saved.saves.last, ayah);
    expect(find.text('تعذّر الحفظ، حاول مرة أخرى'), findsOneWidget);
    expect(find.text('حُفظت الآية ٧ من آل عمران'), findsNothing);
  });

  testWidgets('dragging down closes', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    await tester.fling(find.byType(AyahLeaf), const Offset(0, 300), 1000);
    expect(calls.taps, ['close']);
  });

  testWidgets('a sajda ayah carries the badge', (tester) async {
    await tester.pumpWidget(
      _host(cubit, const AyahIdentifier(surah: 32, ayah: 15), calls),
    );
    expect(find.text('سجدة'), findsOneWidget);
    await tester.pumpWidget(
      _host(cubit, const AyahIdentifier(surah: 32, ayah: 14), calls),
    );
    expect(find.text('سجدة'), findsNothing);
  });

  testWidgets('the banner variant offers the surah actions only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(cubit, const AyahIdentifier(surah: 5, ayah: 0), calls),
    );
    expect(find.text('سورة المائدة'), findsOneWidget);
    expect(find.text('مدنية، ١٢٠ آية'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leaf-surah-start')));
    await tester.tap(find.byKey(const ValueKey('leaf-page')));
    expect(calls.taps, ['start', 'page']);
    expect(find.text('استماع من بداية السورة'), findsOneWidget);
    expect(find.text('استماع الصفحة كاملة'), findsOneWidget);
    expect(find.text('مشاركة'), findsNothing);
    expect(find.text('حفظ الآية'), findsNothing);
    expect(find.text('فاصل'), findsNothing);
    expect(find.textContaining('الآية ٠'), findsNothing);
  });

  testWidgets('share text quotes the ayah and names it', (tester) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('ar'),
        home: Builder(
          builder: (context) {
            text = ayahShareText(
              context,
              const AyahIdentifier(surah: 112, ayah: 1),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(text, '${quran.getVerse(112, 1)} — سورة الإخلاص، الآية ١');
  });

  group('share', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    testWidgets('hands the quoted ayah to the share sheet', (tester) async {
      Object? arguments;
      messenger.setMockMethodCallHandler(channel, (call) async {
        arguments = call.arguments;
        return 'dev.fluttercommunity.plus/share/success';
      });
      await tester.pumpWidget(_host(cubit, ayah, calls));
      await tester.tap(find.byKey(const ValueKey('leaf-share')));
      await tester.pumpAndSettle();
      expect((arguments as Map)['text'], contains(quran.getVerse(3, 7)));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failing share sheet shows the fallback message', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'unavailable'),
      );
      await tester.pumpWidget(_host(cubit, ayah, calls));
      await tester.tap(find.byKey(const ValueKey('leaf-share')));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر فتح نافذة المشاركة'), findsOneWidget);
    });
  });

  testWidgets('the save action announces whether the ayah is saved', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    SemanticsFlags saveFlags() => tester
        .getSemantics(find.byKey(const ValueKey('leaf-save')))
        .getSemanticsData()
        .flagsCollection;

    await tester.pumpWidget(_host(cubit, ayah, calls));
    expect(saveFlags().isButton, isTrue);
    expect(saveFlags().isToggled, Tristate.isFalse);
    final saved = FakeSavedAyatCubit(
      SavedAyatState(items: [savedPlace(ayah)], loaded: true),
    );
    addTearDown(saved.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(saved, ayah, calls));
    expect(saveFlags().isToggled, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('fits at 2x text', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls, scale: 2));
    expect(tester.takeException(), isNull);
  });
}
