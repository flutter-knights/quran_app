import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';

void main() {
  testWidgets('tapping an unselected segment fires onChanged with its value',
      (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: ColorPalette.neutralLight.toThemeData(),
        home: Scaffold(
          body: AppSegmentedSelector<bool>(
            selected: false,
            onChanged: (v) => picked = v == true ? 'on' : 'off',
            options: const [
              SegmentOption(value: false, label: '12h'),
              SegmentOption(value: true, label: '24h'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('24h'));
    await tester.pump();
    expect(picked, 'on');
  });
}
