import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';
import 'package:quran_app/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:quran_app/features/tafsir/presentation/widgets/tafsir_section.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../notifications/presentation/alerts_test_harness.dart';
import '../../tafsir_fakes.dart';

const _ayah = AyahIdentifier(surah: 3, ayah: 7);
const _other = AyahIdentifier(surah: 3, ayah: 8);
const _retry = ValueKey('tafsir-retry');
final _colors = MushafPaper.cream.colors;
final _style = _colors.paperButton();
final _liveRegion = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.liveRegion == true,
);

TafsirLoaded _loaded(AyahIdentifier ayah) => TafsirLoaded(
  ayah,
  Tafsir(surah: ayah.surah, ayah: ayah.ayah, text: tafsirText),
);

Widget _host(
  FakeTafsirCubit cubit, {
  bool lead = false,
  VoidCallback? onTap,
  String locale = 'ar',
  double scale = 1,
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
        child: TafsirSection(
          ayah: _ayah,
          ink: _colors.ink,
          mutedInk: _colors.ink2,
          buttonStyle: _style,
          lead: lead,
          onTap: onTap,
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('loading shows a skeletonized paragraph and no retry', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeTafsirCubit(const TafsirLoading(_ayah))));
    await tester.pump();

    expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsOneWidget);
    expect(find.byKey(_retry), findsNothing);
  });

  testWidgets('a state for another ayah reads as loading', (tester) async {
    await tester.pumpWidget(_host(FakeTafsirCubit(_loaded(_other))));
    await tester.pump();

    expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsOneWidget);
    expect(find.text(tafsirText), findsNothing);
  });

  testWidgets('loaded shows the text at regular16 with line height 1.95', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeTafsirCubit(_loaded(_ayah))));
    await tester.pumpAndSettle();

    final style = tester
        .widget<Text>(find.byKey(const ValueKey('tafsir-body')))
        .style!;
    expect(style.fontSize, TS.regular16.fontSize);
    expect(style.height, 1.95);
    expect(style.color, _colors.ink);
    expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsNothing);
  });

  testWidgets('failed offers إعادة المحاولة that retries', (tester) async {
    final cubit = FakeTafsirCubit(const TafsirFailed(_ayah));
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    expect(find.text('تعذّر تحميل التفسير'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(_retry)).style, _style);

    await tester.tap(find.byKey(_retry));
    await tester.pump();

    expect(cubit.retries, 1);
  });

  testWidgets('the retry reads as a control, not a second sentence', (
    tester,
  ) async {
    final cubit = FakeTafsirCubit(const TafsirFailed(_ayah));
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    final retry = find.byKey(_retry);
    expect(
      find.descendant(of: retry, matching: find.byType(HugeIcon)),
      findsOneWidget,
    );
    final label = tester.widget<Text>(
      find.descendant(of: retry, matching: find.text('إعادة المحاولة')),
    );
    expect(label.style?.fontWeight, FontWeight.w600);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
  });

  testWidgets('the one-line lead retries from a labelled refresh button', (
    tester,
  ) async {
    final cubit = FakeTafsirCubit(const TafsirFailed(_ayah));
    await tester.pumpWidget(_host(cubit, lead: true));
    await tester.pumpAndSettle();

    final retry = find.byKey(_retry);
    expect(
      find.descendant(of: retry, matching: find.byType(HugeIcon)),
      findsOneWidget,
    );
    expect(find.byTooltip('إعادة المحاولة'), findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(retry).width, greaterThanOrEqualTo(48));

    await tester.tap(retry);
    await tester.pump();
    expect(cubit.retries, 1);
  });

  testWidgets('the lead retry ripples in the paper ink', (tester) async {
    await tester.pumpWidget(
      _host(FakeTafsirCubit(const TafsirFailed(_ayah)), lead: true),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(find.byKey(_retry)).style, _style);
  });

  testWidgets('the lead retry retries without opening the tafsir', (
    tester,
  ) async {
    var taps = 0;
    final cubit = FakeTafsirCubit(const TafsirFailed(_ayah));
    await tester.pumpWidget(_host(cubit, lead: true, onTap: () => taps++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تعذّر تحميل التفسير'));
    expect(taps, 1);
    expect(cubit.retries, 0);

    await tester.tap(find.byKey(_retry));
    await tester.pump();
    expect(cubit.retries, 1);
    expect(taps, 1);
  });

  testWidgets('the lead retry is announced as a named button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(FakeTafsirCubit(const TafsirFailed(_ayah)), lead: true),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(_retry)),
      isSemantics(
        tooltip: 'إعادة المحاولة',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('full mode names the book, the caption and the source', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeTafsirCubit(_loaded(_ayah))));
    await tester.pumpAndSettle();

    expect(find.text('التفسير الميسر'), findsOneWidget);
    expect(
      find.text('يُحمَّل من الإنترنت ثم يُحفظ على الجهاز'),
      findsOneWidget,
    );
    expect(
      find.text('المصدر: التفسير الميسر، مجمع الملك فهد، عبر alquran.cloud'),
      findsOneWidget,
    );
  });

  testWidgets('lead mode shows one line with an ellipsis and opens on tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(FakeTafsirCubit(_loaded(_ayah)), lead: true, onTap: () => taps++),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(tafsirText));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(find.text('التفسير الميسر'), findsNothing);
    expect(find.textContaining('المصدر'), findsNothing);

    await tester.tap(find.text(tafsirText));
    expect(taps, 1);
  });

  testWidgets('lead mode failure keeps the retry in one row', (tester) async {
    await tester.pumpWidget(
      _host(FakeTafsirCubit(const TafsirFailed(_ayah)), lead: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذّر تحميل التفسير'), findsOneWidget);
    expect(find.byKey(_retry), findsOneWidget);
    final row = find
        .ancestor(
          of: find.text('تعذّر تحميل التفسير'),
          matching: find.byType(Row),
        )
        .first;
    expect(
      find.descendant(of: row, matching: find.byKey(_retry)),
      findsOneWidget,
    );
    expect(_liveRegion, findsOneWidget);
  });

  testWidgets('full mode failure is a live region', (tester) async {
    await tester.pumpWidget(_host(FakeTafsirCubit(const TafsirFailed(_ayah))));
    await tester.pumpAndSettle();

    expect(_liveRegion, findsOneWidget);
  });

  testWidgets('lead skeleton lays out right-to-left in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FakeTafsirCubit(const TafsirLoading(_ayah)),
        lead: true,
        locale: 'en',
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.textContaining('تفسير مؤقت'));
    expect(text.textDirection, TextDirection.rtl);
  });

  testWidgets('lead failure fits at 2x text in 360 px', (tester) async {
    await tester.pumpWidget(
      _host(FakeTafsirCubit(const TafsirFailed(_ayah)), lead: true, scale: 2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(_retry), findsOneWidget);
  });

  for (final (locale, message) in [
    ('ar', 'تعذّر تحميل التفسير'),
    ('en', "Couldn't load the tafsir"),
  ]) {
    testWidgets('lead failure message is not ellipsized in $locale at 1.7x', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          FakeTafsirCubit(const TafsirFailed(_ayah)),
          lead: true,
          scale: 1.7,
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(message),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    });
  }

  testWidgets('full mode lists the source right after the caption', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeTafsirCubit(_loaded(_ayah))));
    await tester.pumpAndSettle();

    final caption = tester.getTopLeft(
      find.text('يُحمَّل من الإنترنت ثم يُحفظ على الجهاز'),
    );
    final source = tester.getTopLeft(
      find.text('المصدر: التفسير الميسر، مجمع الملك فهد، عبر alquran.cloud'),
    );
    final body = tester.getTopLeft(find.byKey(const ValueKey('tafsir-body')));
    expect(source.dy, greaterThan(caption.dy));
    expect(body.dy, greaterThan(source.dy));
  });

  testWidgets('the body stays right-to-left in English', (tester) async {
    await tester.pumpWidget(
      _host(FakeTafsirCubit(_loaded(_ayah)), locale: 'en'),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tafsir-body')))
          .textDirection,
      TextDirection.rtl,
    );
  });
}
