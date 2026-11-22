import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/utils/screen_wake.dart';

class _RecordingWake extends ScreenWake {
  final calls = <bool>[];

  @override
  Future<void> set(bool on) async => calls.add(on);
}

void main() {
  test('the screen stays awake while any reader still holds it', () async {
    final wake = _RecordingWake();
    final outer = Object();
    final nested = Object();

    await wake.hold(outer, on: true);
    await wake.hold(nested, on: true);
    await wake.hold(nested, on: false);

    expect(wake.calls.last, isTrue);

    await wake.hold(outer, on: false);

    expect(wake.calls.last, isFalse);
  });

  test(
    'a reader that turns the setting off releases only its own hold',
    () async {
      final wake = _RecordingWake();
      final a = Object();
      final b = Object();

      await wake.hold(a, on: true);
      await wake.hold(b, on: true);
      await wake.hold(a, on: false);

      expect(wake.calls.last, isTrue);

      await wake.hold(b, on: false);
      expect(wake.calls.last, isFalse);
    },
  );
}
