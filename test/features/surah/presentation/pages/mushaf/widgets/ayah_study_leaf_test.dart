import 'dart:ui' show SemanticsFlags, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/ayah_share_sheet.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../ayah_share/ayah_share_fakes.dart';
import '../../../../../tafsir/tafsir_fakes.dart';

const _ayah = AyahIdentifier(surah: 3, ayah: 7);

class _Calls {
  final taps = <String>[];
  VoidCallback tap(String name) =>
      () => taps.add(name);
}

Widget _host(
  FakeTafsirCubit cubit,
  _Calls calls, {
  MushafPaperColors? colors,
  String locale = 'ar',
  double scale = 1,
  bool previous = true,
  bool next = true,
}) => MaterialApp(
  localizationsDelegates: const [
    S.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: S.delegate.supportedLocales,
  locale: Locale(locale),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: BlocProvider<TafsirCubit>.value(
      value: cubit,
      child: SizedBox(
        width: 360,
        height: 640,
        child: AyahStudyLeaf(
          ayah: _ayah,
          page: 50,
          lines: const [],
          colors: colors ?? MushafPaper.cream.colors,
          onBack: calls.tap('back'),
          onPrevious: previous ? calls.tap('previous') : null,
          onNext: next ? calls.tap('next') : null,
        ),
      ),
    ),
  ),
);

ButtonStyleButton _button(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key)));

void main() {
  late FakeTafsirCubit cubit;
  late _Calls calls;

  setUp(() {
    cubit = FakeTafsirCubit()..load(_ayah);
    calls = _Calls();
    addTearDown(cubit.close);
  });

  testWidgets('the header carries العودة إلى المصحف, the title and مشاركة', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, calls));
    expect(find.text('آل عمران، الآية ٧'), findsOneWidget);
    expect(find.text('العودة إلى المصحف'), findsOneWidget);
    expect(find.text('مشاركة'), findsOneWidget);
  });

  testWidgets('shows the strip and المصحف خلفك على هذه الآية', (tester) async {
    await tester.pumpWidget(_host(cubit, calls));
    expect(find.byType(AyahStrip), findsOneWidget);
    expect(find.text('المصحف خلفك على هذه الآية'), findsOneWidget);
  });

  testWidgets(
    'التفسير is selected and the other three are disabled with لاحقًا',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(cubit, calls));
      SemanticsFlags flags(String key) => tester
          .getSemantics(find.byKey(ValueKey(key)))
          .getSemanticsData()
          .flagsCollection;
      expect(flags('study-chip-tafsir').isSelected, Tristate.isTrue);
      expect(flags('study-chip-tafsir').isEnabled, Tristate.isTrue);
      for (final key in [
        'study-chip-translation',
        'study-chip-words',
        'study-chip-note',
      ]) {
        expect(flags(key).isEnabled, Tristate.isFalse);
        expect(flags(key).isSelected, Tristate.isFalse);
      }
      expect(find.text('لاحقًا'), findsNWidgets(3));
      for (final label in ['التفسير', 'الترجمة', 'معاني الكلمات', 'ملاحظتي']) {
        expect(find.text(label), findsOneWidget);
      }
      handle.dispose();
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('all four section chips show at 360 px, text ${scale}x', (
      tester,
    ) async {
      await tester.pumpWidget(_host(cubit, calls, scale: scale));
      await tester.pumpAndSettle();
      for (final chip in ['tafsir', 'translation', 'words', 'note']) {
        final rect = tester.getRect(find.byKey(ValueKey('study-chip-$chip')));
        expect(rect.left, greaterThanOrEqualTo(0), reason: chip);
        expect(rect.right, lessThanOrEqualTo(360), reason: chip);
      }
    });
  }

  testWidgets('التفسير is the first chip, at the right edge in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, calls));
    await tester.pumpAndSettle();
    final tafsir = tester.getRect(
      find.byKey(const ValueKey('study-chip-tafsir')),
    );
    final translation = tester.getRect(
      find.byKey(const ValueKey('study-chip-translation')),
    );
    expect(tafsir.left, greaterThan(translation.left));
  });

  testWidgets('the book row, caption, body and source show', (tester) async {
    await tester.pumpWidget(_host(cubit, calls));
    expect(find.text('التفسير الميسر'), findsOneWidget);
    expect(
      find.text('يُحمَّل من الإنترنت ثم يُحفظ على الجهاز'),
      findsOneWidget,
    );
    expect(find.text(tafsirText), findsOneWidget);
    expect(
      find.text('المصدر: التفسير الميسر، مجمع الملك فهد، عبر alquran.cloud'),
      findsOneWidget,
    );
  });

  testWidgets(
    'previous and next reach their handlers; a null one is disabled',
    (tester) async {
      await tester.pumpWidget(_host(cubit, calls));
      await tester.ensureVisible(find.byKey(const ValueKey('study-previous')));
      await tester.tap(find.byKey(const ValueKey('study-previous')));
      await tester.tap(find.byKey(const ValueKey('study-next')));
      expect(calls.taps, ['previous', 'next']);
      expect(find.text('الآية السابقة'), findsOneWidget);
      expect(find.text('الآية التالية'), findsOneWidget);
      await tester.pumpWidget(
        _host(cubit, calls, previous: false, next: false),
      );
      expect(_button(tester, 'study-previous').onPressed, isNull);
      expect(_button(tester, 'study-next').onPressed, isNull);
    },
  );

  testWidgets('العودة إلى المصحف and a drag down on the header call onBack', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, calls));
    await tester.tap(find.byKey(const ValueKey('study-back')));
    expect(calls.taps, ['back']);
    await tester.fling(
      find.text('آل عمران، الآية ٧'),
      const Offset(0, 200),
      1000,
    );
    await tester.pumpAndSettle();
    expect(calls.taps, ['back', 'back']);
  });

  testWidgets('the buttons take the paper ink on night paper', (tester) async {
    final colors = MushafPaper.night.colors;
    await tester.pumpWidget(_host(cubit, calls, colors: colors));
    await tester.ensureVisible(find.byKey(const ValueKey('study-next')));
    for (final key in [
      'study-back',
      'study-share',
      'study-previous',
      'study-next',
    ]) {
      final style = _button(tester, key).style!;
      expect(style.foregroundColor!.resolve({}), colors.ink, reason: key);
    }
    await tester.pumpWidget(
      _host(cubit, calls, colors: colors, previous: false, next: false),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('study-next')));
    for (final key in ['study-previous', 'study-next']) {
      final style = _button(tester, key).style!;
      expect(
        style.foregroundColor!.resolve({WidgetState.disabled}),
        colors.ink.withValues(alpha: 0.38),
        reason: key,
      );
    }
  });

  testWidgets('the arrows follow the reading direction in English', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, calls, locale: 'en'));
    await tester.ensureVisible(find.byKey(const ValueKey('study-next')));
    final context = tester.element(find.byKey(const ValueKey('study-next')));
    final icon = tester.widget<HugeIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('study-next')),
        matching: find.byType(HugeIcon),
      ),
    );
    expect(icon.icon, forwardArrowIcon(context));
    expect(icon.icon, HugeIcons.strokeRoundedArrowRight02);
    final body = tester.widget<Text>(find.byKey(const ValueKey('tafsir-body')));
    expect(body.textDirection, TextDirection.rtl);
  });

  testWidgets('the step arrows and their sides follow RTL in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, calls));
    await tester.ensureVisible(find.byKey(const ValueKey('study-next')));
    final context = tester.element(find.byKey(const ValueKey('study-next')));
    Finder icon(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(HugeIcon),
    );
    Finder label(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Text),
    );
    expect(
      tester.widget<HugeIcon>(icon('study-previous')).icon,
      backArrowIcon(context),
    );
    expect(
      tester.widget<HugeIcon>(icon('study-next')).icon,
      forwardArrowIcon(context),
    );
    expect(
      tester.getCenter(icon('study-previous')).dx,
      greaterThan(tester.getCenter(label('study-previous')).dx),
    );
    expect(
      tester.getCenter(icon('study-next')).dx,
      lessThan(tester.getCenter(label('study-next')).dx),
    );
  });

  testWidgets('fits at 2x text in 360 px', (tester) async {
    await tester.pumpWidget(_host(cubit, calls, scale: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the share button opens the share sheet', (tester) async {
    final fakes = registerFakeAyahShare();
    addTearDown(sl.reset);
    await tester.pumpWidget(_host(cubit, calls));
    await tester.tap(find.byKey(const ValueKey('study-share')));
    await tester.pumpAndSettle();
    expect(find.byType(AyahShareSheet), findsOneWidget);
    expect(fakes.content.requests, [_ayah]);
  });
}
