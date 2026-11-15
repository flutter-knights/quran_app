import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget tile) => tester.pumpWidget(
    MaterialApp(
      theme: ColorPalette.neutralLight.toThemeData(),
      home: Scaffold(body: tile),
    ),
  );

  testWidgets('shows title and subtitle and taps when enabled', (tester) async {
    var taps = 0;
    await pump(
      tester,
      AppSettingsTile(title: 'Title', subtitle: 'Sub', onTap: () => taps++),
    );
    expect(find.text('Sub'), findsOneWidget);
    await tester.tap(find.text('Title'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(AppSettingsTile)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('disabled tile is dimmed and ignores taps', (tester) async {
    var taps = 0;
    await pump(
      tester,
      AppSettingsTile(title: 'Title', enabled: false, onTap: () => taps++),
    );
    await tester.tap(find.text('Title'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 0);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Title'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.38);
  });
}
