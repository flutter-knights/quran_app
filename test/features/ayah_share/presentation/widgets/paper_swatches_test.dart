import 'dart:ui' show SemanticsFlags, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/paper_swatches.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  testWidgets('six 48 px swatches, the selected one announced selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    MushafPaper? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: PaperSwatches(
            selected: MushafPaper.sepia,
            onSelected: (paper) => picked = paper,
          ),
        ),
      ),
    );

    for (final paper in MushafPaper.values) {
      final size = tester.getSize(
        find.byKey(ValueKey('share-paper-${paper.name}')),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(MushafPaper.values, hasLength(6));
    SemanticsFlags flags(String name) => tester
        .getSemantics(find.byKey(ValueKey('share-paper-$name')))
        .getSemanticsData()
        .flagsCollection;
    expect(flags('sepia').isSelected, Tristate.isTrue);
    expect(flags('cream').isSelected, Tristate.isFalse);

    await tester.tap(find.byKey(const ValueKey('share-paper-cream')));
    expect(picked, MushafPaper.cream);
    handle.dispose();
  });
}
