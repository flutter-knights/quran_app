import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';

Future<(IconData, IconData)> _glyphs(
  WidgetTester tester,
  TextDirection direction,
) async {
  late (IconData, IconData) glyphs;
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Builder(
        builder: (context) {
          glyphs = (skipBackIcon(context), skipForwardIcon(context));
          return const SizedBox();
        },
      ),
    ),
  );
  return glyphs;
}

void main() {
  testWidgets('skip glyphs follow the reading direction', (tester) async {
    expect(await _glyphs(tester, TextDirection.ltr), (
      Icons.skip_previous,
      Icons.skip_next,
    ));
    expect(await _glyphs(tester, TextDirection.rtl), (
      Icons.skip_next,
      Icons.skip_previous,
    ));
  });
}
