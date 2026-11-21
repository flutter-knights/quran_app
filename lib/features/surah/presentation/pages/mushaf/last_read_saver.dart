import 'dart:async';

import '../../../domain/entities/last_read.dart';
import 'mushaf_args.dart';

/// Debounced + immediate persistence of the reading position, guarded after a
/// jump arrival. Pure timing
/// logic, decoupled from the widget so it is unit-testable. The page widget
/// owns a [LastReadSaver] and supplies [readCurrent] + [persist].
class LastReadSaver {
  LastReadSaver({
    required this.readCurrent,
    required this.persist,
    required MushafOrigin origin,
    this.now = DateTime.now,
    this.debounce = const Duration(milliseconds: 800),
    this.dwell = const Duration(seconds: 20),
  }) : _guarded = origin == MushafOrigin.jump {
    if (_guarded) _startDwell();
  }

  final LastRead Function() readCurrent;
  final Future<void> Function(LastRead) persist;
  final DateTime Function() now;
  final Duration debounce;
  final Duration dwell;

  bool _guarded;
  bool get guarded => _guarded;

  Timer? _timer;
  Timer? _dwellTimer;

  void _startDwell() {
    _dwellTimer?.cancel();
    _dwellTimer = Timer(dwell, () {
      _guarded = false;
      _write();
    });
  }

  void _write() {
    final c = readCurrent();
    persist(LastRead(page: c.page, ayah: c.ayah, updatedAt: now()));
  }

  void schedule() {
    if (_guarded) return _startDwell();
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void flush() {
    _timer?.cancel();
    if (!_guarded) _write();
  }

  void onManualTurn() {
    _guarded = false;
    _dwellTimer?.cancel();
  }

  void rearm() {
    if (_timer?.isActive ?? false) flush();
    _guarded = true;
    _startDwell();
  }

  void dispose() {
    _timer?.cancel();
    _dwellTimer?.cancel();
  }
}
