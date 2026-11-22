import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenWake {
  const ScreenWake();

  static final _holders = <Object>{};

  Future<void> hold(Object owner, {required bool on}) {
    on ? _holders.add(owner) : _holders.remove(owner);
    return set(_holders.isNotEmpty);
  }

  Future<void> set(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {}
  }
}
