import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  testWidgets('renders surah glyph, juz glyph, and page-number ornament',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MushafPrintedChrome(
          pageNumber: 2,
          colors: MushafPaper.cream.colors,
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('printed-chrome-surah')), findsOneWidget);
    expect(find.byKey(const ValueKey('printed-chrome-juz')), findsOneWidget);
    final pageText = tester.widget<Text>(
      find.byKey(const ValueKey('printed-chrome-page')),
    );
    expect(pageText.data, contains('٢')); // page 2 in Arabic-Indic digits
  });

  testWidgets('surah glyph uses the QCF2BSML font family', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MushafPrintedChrome(
          pageNumber: 1,
          colors: MushafPaper.night.colors,
        ),
      ),
    ));
    final surah = tester.widget<Text>(
      find.byKey(const ValueKey('printed-chrome-surah')),
    );
    expect(surah.style?.fontFamily, 'QCF2BSML');
    expect(surah.style?.color, MushafPaper.night.colors.accent);
  });
}
