import 'dart:async';

import '../../../domain/entities/last_read.dart';

/// Debounced + immediate persistence of the reading position. Pure timing
/// logic, decoupled from the widget so it is unit-testable. The page widget
/// owns a [LastReadSaver] and supplies [readCurrent] + [persist].
class LastReadSaver {
  LastReadSaver({
    required this.readCurrent,
    required this.persist,
    this.debounce = const Duration(milliseconds: 800),
  });

  final LastRead Function() readCurrent;
  final Future<void> Function(LastRead) persist;
  final Duration debounce;

  Timer? _timer;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void flush() {
    _timer?.cancel();
    persist(readCurrent());
  }

  void dispose() => _timer?.cancel();
}
