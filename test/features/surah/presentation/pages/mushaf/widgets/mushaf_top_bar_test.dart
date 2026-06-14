import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart';

void main() {
  Widget host({required VoidCallback onBack, required VoidCallback onJump}) =>
      MaterialApp(
        home: Scaffold(
          body: MushafTopBar(
            surahName: 'Al-Baqarah',
            pageNumber: 3,
            localeCode: 'en',
            onBack: onBack,
            onJump: onJump,
          ),
        ),
      );

  testWidgets('shows surah name and page number', (tester) async {
    await tester.pumpWidget(host(onBack: () {}, onJump: () {}));
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('back button fires onBack', (tester) async {
    var backs = 0;
    await tester.pumpWidget(host(onBack: () => backs++, onJump: () {}));
    await tester.tap(find.byKey(const ValueKey('mushaf-top-back')));
    expect(backs, 1);
  });

  testWidgets('tapping the page area fires onJump', (tester) async {
    var jumps = 0;
    await tester.pumpWidget(host(onBack: () {}, onJump: () => jumps++));
    await tester.tap(find.byKey(const ValueKey('mushaf-top-page')));
    expect(jumps, 1);
  });
}
