import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/widgets/design/app_option_sheet.dart';

void main() {
  late List<int> picked;
  late int closed;

  Future<void> open(WidgetTester tester) async {
    picked = [];
    closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ColorPalette.neutralLight.toThemeData(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppOptionSheet<int>(
                context: context,
                title: 'Pick',
                selected: 2,
                onSelected: picked.add,
                onClosed: () => closed++,
                footer: const Text('f'),
                options: const [
                  AppOption(
                    value: 1,
                    label: 'One',
                    trailing: Icon(Icons.play_arrow),
                  ),
                  AppOption(value: 2, label: 'Two'),
                  AppOption(value: 3, label: 'Three', subtitle: 'third'),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('marks the selected option and renders trailing and footer', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Pick'), findsOneWidget);
    final group = tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>));
    expect(group.groupValue, 2);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('f')).dy,
      greaterThan(tester.getTopLeft(find.text('Three')).dy),
    );
  });

  testWidgets(
    'selecting an option calls onSelected, closes and fires onClosed once',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Three'));
      await tester.pumpAndSettle();
      expect(picked, [3]);
      expect(find.text('Pick'), findsNothing);
      expect(closed, 1);
    },
  );

  testWidgets(
    'a barrier tap closes without selecting and fires onClosed once',
    (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      expect(find.text('Pick'), findsNothing);
      expect(closed, 1);
    },
  );
}
