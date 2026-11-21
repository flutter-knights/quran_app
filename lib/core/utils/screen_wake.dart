import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenWake {
  const ScreenWake();

  Future<void> set(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {}
  }
}
