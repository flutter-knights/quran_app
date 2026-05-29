import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart';

void main() {
  test('verse low on page -> popover above', () {
    expect(popoverPlacement(verseCenterY: 0.8), PopoverPlacement.above);
  });
  test('verse high on page -> popover below', () {
    expect(popoverPlacement(verseCenterY: 0.2), PopoverPlacement.below);
  });
}
