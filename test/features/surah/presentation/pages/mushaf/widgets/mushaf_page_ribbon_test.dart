import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart';

void main() {
  testWidgets('renders and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            MushafPageRibbon(color: Colors.red, onTap: () => taps++),
          ],
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('mushaf-page-ribbon')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mushaf-page-ribbon')));
    expect(taps, 1);
  });
}
