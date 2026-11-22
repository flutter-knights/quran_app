import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/khatam_medallion.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

Widget _host({double scale = 1, MushafPaper paper = MushafPaper.cream}) =>
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ar'), Locale('en')],
      locale: const Locale('ar'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: KhatamMedallion(label: '٦٠٤', colors: paper.colors),
        ),
      ),
    );

void main() {
  testWidgets('shows the label', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('٦٠٤'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('stays within 44 px at ${scale}x text', (tester) async {
      await tester.pumpWidget(_host(scale: scale));
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(KhatamMedallion));
      expect(size.width, lessThanOrEqualTo(44));
      expect(size.height, lessThanOrEqualTo(44));
    });
  }

  testWidgets('repaints when the paper colour changes', (tester) async {
    await tester.pumpWidget(_host());
    CustomPaint paint() => tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(KhatamMedallion),
        matching: find.byType(CustomPaint),
      ),
    );
    final cream = paint().painter!;
    await tester.pumpWidget(_host(paper: MushafPaper.night));
    expect(paint().painter!.shouldRepaint(cream), isTrue);
  });
}
