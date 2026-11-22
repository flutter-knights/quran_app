import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/assets_dir.dart';

void main() {
  test('mushafPage pads the page number to three digits', () {
    expect(AssetsDir.mushafPage(7), 'assets/mushaf/pages/page_007.png');
  });
}
