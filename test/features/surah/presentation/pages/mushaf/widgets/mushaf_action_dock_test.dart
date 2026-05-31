import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart';

void main() {
  testWidgets('dock shows settings, play, and bookmark buttons',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: MushafActionDock())),
    ));
    expect(find.byKey(const ValueKey('dock-reading-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-bookmark')), findsOneWidget);
  });
}
