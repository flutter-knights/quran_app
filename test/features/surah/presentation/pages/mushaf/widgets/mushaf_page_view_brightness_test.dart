import 'package:flutter_test/flutter_test.dart';

void main() {
  // Pure formula guard: the scrim alpha is (1 - brightness).
  test('scrim alpha is the inverse of page brightness', () {
    double scrimAlpha(double brightness) => 1.0 - brightness;
    expect(scrimAlpha(1.0), 0.0);
    expect(scrimAlpha(0.6), closeTo(0.4, 1e-9));
    expect(scrimAlpha(0.3), closeTo(0.7, 1e-9));
  });
}
