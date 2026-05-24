// test/core/constants/color_palette_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/color_palette.dart';

void main() {
  test('ColorPalette has exactly 4 values', () {
    expect(ColorPalette.values.length, 4);
  });

  test('values are named correctly', () {
    expect(ColorPalette.neutralDark.name, 'neutralDark');
    expect(ColorPalette.neutralLight.name, 'neutralLight');
    expect(ColorPalette.slateDark.name, 'slateDark');
    expect(ColorPalette.slateLight.name, 'slateLight');
  });
}
