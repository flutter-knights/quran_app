import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/widgets/design/action_buttons_row.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoidCallback? onPressed) =>
      tester.pumpWidget(
        MaterialApp(
          theme: ColorPalette.neutralLight.toThemeData(),
          home: Scaffold(
            body: ActionBtn.primary(
              icon: const SizedBox(),
              label: 'Go',
              onPressed: onPressed,
            ),
          ),
        ),
      );

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(ActionBtn),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  testWidgets('a button without onPressed is dimmed', (tester) async {
    await pump(tester, null);
    expect(opacity(tester), 0.38);
  });

  testWidgets('a button with onPressed is drawn in full and taps', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, () => taps++);
    expect(opacity(tester), 1);
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });
}
