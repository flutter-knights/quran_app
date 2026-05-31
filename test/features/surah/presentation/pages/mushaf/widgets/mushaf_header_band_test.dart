import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_header_band.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  testWidgets('header band renders surah + juz glyphs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 34,
          child: MushafHeaderBand(
            pageNumber: 2,
            colors: MushafPaper.cream.colors,
          ),
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('printed-chrome-surah')), findsOneWidget);
    expect(find.byKey(const ValueKey('printed-chrome-juz')), findsOneWidget);
  });

  testWidgets('surah glyph uses the QCF2BSML font family and accent color',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 34,
          child: MushafHeaderBand(
            pageNumber: 1,
            colors: MushafPaper.night.colors,
          ),
        ),
      ),
    ));
    final surah = tester.widget<Text>(
      find.byKey(const ValueKey('printed-chrome-surah')),
    );
    expect(surah.style?.fontFamily, 'QCF2BSML');
    expect(surah.style?.color, MushafPaper.night.colors.accent);
  });

  testWidgets('page-number ornament shows the Arabic-Indic page number',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MushafPageNumberOrnament(
          pageNumber: 2,
          colors: MushafPaper.cream.colors,
        ),
      ),
    ));
    final pageText = tester.widget<Text>(
      find.byKey(const ValueKey('printed-chrome-page')),
    );
    expect(pageText.data, contains('٢'));
  });
}
