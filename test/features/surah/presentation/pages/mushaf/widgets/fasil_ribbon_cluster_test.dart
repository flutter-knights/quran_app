import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextDirection direction = TextDirection.rtl,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Align(
        alignment: Alignment.topLeft,
        child: Stack(children: [Positioned(left: 0, top: 0, child: child)]),
      ),
    ),
  );

  testWidgets('draws nothing when no فاصل is placed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: FasilRibbonCluster(
                placed: const {},
                paper: MushafPaper.sepia,
                onTap: () => taps += 100,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 1);
    expect(find.byKey(const ValueKey('fasil-cluster')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('fasil-cluster'))),
      Size.zero,
    );
  });

  testWidgets('one tap target labelled with the placed names', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      FasilRibbonCluster(
        placed: const {FasilSlot.wird: 'الورد', FasilSlot.muraja: 'المراجعة'},
        paper: MushafPaper.sepia,
        onTap: () => taps++,
      ),
    );
    final cluster = find.byKey(const ValueKey('fasil-cluster'));
    expect(tester.getSize(cluster), const Size(48, 56));
    expect(find.bySemanticsLabel('الفواصل: الورد، المراجعة'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('الفواصل: الورد، المراجعة')),
      matchesSemantics(
        label: 'الفواصل: الورد، المراجعة',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(cluster);
    expect(taps, 1);
    handle.dispose();
  });

  for (final direction in TextDirection.values) {
    testWidgets('only placed ribbons are drawn, from the left in $direction', (
      tester,
    ) async {
      await pump(
        tester,
        FasilRibbonCluster(
          placed: const {FasilSlot.wird: 'الورد', FasilSlot.muraja: 'المراجعة'},
          paper: MushafPaper.sepia,
          onTap: () {},
        ),
        direction: direction,
      );
      final cluster = find.byKey(const ValueKey('fasil-cluster'));
      double x(String slot) =>
          tester.getTopLeft(find.byKey(ValueKey('fasil-rib-$slot'))).dx -
          tester.getTopLeft(cluster).dx;
      expect(x('wird'), 4);
      expect(x('muraja'), 32);
      expect(find.byKey(const ValueKey('fasil-rib-hifz')), findsNothing);
    });
  }

  testWidgets('the tail tab prints its name and is 48 by 88', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      FasilTailTab(
        slot: FasilSlot.hifz,
        name: 'الحفظ',
        paper: MushafPaper.sepia,
        onTap: () => taps++,
      ),
    );
    final tab = find.byKey(const ValueKey('fasil-tail-hifz'));
    expect(find.text('الحفظ'), findsOneWidget);
    expect(tester.getSize(tab), const Size(48, 88));
    expect(
      tester.getSemantics(find.bySemanticsLabel('الحفظ')),
      matchesSemantics(label: 'الحفظ', isButton: true, hasTapAction: true),
    );
    await tester.tap(tab);
    expect(taps, 1);
    handle.dispose();
  });

  for (final direction in TextDirection.values) {
    testWidgets('the tail label sits under its ribbon in $direction', (
      tester,
    ) async {
      for (final (slot, left) in [
        (FasilSlot.wird, 0.0),
        (FasilSlot.hifz, 8.0),
        (FasilSlot.muraja, 22.0),
      ]) {
        await pump(
          tester,
          FasilTailTab(
            slot: slot,
            name: 'اسم',
            paper: MushafPaper.sepia,
            onTap: () {},
          ),
          direction: direction,
        );
        final tab = find.byKey(ValueKey('fasil-tail-${slot.name}'));
        final label = find.descendant(
          of: tab,
          matching: find.byKey(const ValueKey('fasil-tail-label')),
        );
        expect(tester.getTopLeft(label).dx - tester.getTopLeft(tab).dx, left);
        expect(tester.getSize(label).width, 22);
      }
    });
  }

  testWidgets('a long name ellipsizes inside the tab', (tester) async {
    await pump(
      tester,
      FasilTailTab(
        slot: FasilSlot.wird,
        name: 'حفظ سورة البقرة كاملة',
        paper: MushafPaper.sepia,
        onTap: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('fasil-tail-wird'))),
      const Size(48, 88),
    );
  });

  testWidgets('tail text uses the paper background', (tester) async {
    await pump(
      tester,
      FasilTailTab(
        slot: FasilSlot.wird,
        name: 'الورد',
        paper: MushafPaper.sepia,
        onTap: () {},
      ),
    );
    final style = tester.widget<Text>(find.text('الورد')).style!;
    expect(style.color, MushafPaper.sepia.colors.background);
    expect(style.height, 22 / 14);
  });

  testWidgets('the strip ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: 18,
              top: 0,
              width: 12,
              height: 200,
              child: FasilStrip(slot: FasilSlot.hifz, paper: MushafPaper.sepia),
            ),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(24, 100));
    expect(taps, 1);
  });

  testWidgets('a strip stitches to its bottom edge', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned(
              left: 18,
              top: 0,
              width: 12,
              height: 200,
              child: FasilStrip(slot: FasilSlot.hifz, paper: MushafPaper.sepia),
            ),
          ],
        ),
      ),
    );
    final paint = find.descendant(
      of: find.byKey(const ValueKey('fasil-strip-hifz')),
      matching: find.byType(CustomPaint),
    );
    var lastStitch = 0.0;
    expect(
      tester.renderObject(paint.first),
      paints..everything((method, arguments) {
        if (method == #drawLine) {
          lastStitch = (arguments[1] as Offset).dy;
        }
        return true;
      }),
    );
    expect(lastStitch, 200);
  });

  testWidgets('the tail tab draws no stitches', (tester) async {
    await pump(
      tester,
      FasilTailTab(
        slot: FasilSlot.wird,
        name: 'الورد',
        paper: MushafPaper.sepia,
        onTap: () {},
      ),
    );
    final paint = find.descendant(
      of: find.byKey(const ValueKey('fasil-tail-label')),
      matching: find.byType(CustomPaint),
    );
    expect(tester.renderObject(paint.first), isNot(paints..line()));
  });
}
