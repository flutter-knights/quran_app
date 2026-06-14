import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart';

void main() {
  Widget host({
    required bool isSaved,
    required VoidCallback onSettings,
    required VoidCallback onPlay,
    required VoidCallback onToggleSave,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MushafBrowseBar(
              isSaved: isSaved,
              onSettings: onSettings,
              onPlay: onPlay,
              onToggleSave: onToggleSave,
            ),
          ),
        ),
      );

  testWidgets('shows settings, play, save buttons (no rotate)', (tester) async {
    await tester.pumpWidget(host(
      isSaved: false, onSettings: () {}, onPlay: () {}, onToggleSave: () {}));
    expect(find.byKey(const ValueKey('browse-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('browse-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('browse-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('browse-rotate')), findsNothing);
  });

  testWidgets('each button fires its callback', (tester) async {
    var settings = 0, play = 0, save = 0;
    await tester.pumpWidget(host(
      isSaved: false,
      onSettings: () => settings++,
      onPlay: () => play++,
      onToggleSave: () => save++,
    ));
    await tester.tap(find.byKey(const ValueKey('browse-settings')));
    await tester.tap(find.byKey(const ValueKey('browse-play')));
    await tester.tap(find.byKey(const ValueKey('browse-save')));
    expect([settings, play, save], [1, 1, 1]);
  });

  testWidgets('save icon reflects isSaved', (tester) async {
    await tester.pumpWidget(host(
      isSaved: true, onSettings: () {}, onPlay: () {}, onToggleSave: () {}));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_outline), findsNothing);
  });
}
