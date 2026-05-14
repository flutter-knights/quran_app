import 'dart:collection';

import '../../domain/entities/mushaf_page_entity.dart';

typedef _EvictionListener = void Function(int pageNumber);

class MushafPageCache {
  MushafPageCache({required this.capacity}) : assert(capacity > 0);

  final int capacity;
  final LinkedHashMap<int, MushafPageEntity> _entries = LinkedHashMap();
  final List<_EvictionListener> _listeners = [];

  MushafPageEntity? get(int pageNumber) {
    final value = _entries.remove(pageNumber);
    if (value == null) return null;
    _entries[pageNumber] = value;
    return value;
  }

  void put(int pageNumber, MushafPageEntity entity) {
    _entries.remove(pageNumber);
    _entries[pageNumber] = entity;
    while (_entries.length > capacity) {
      final oldestKey = _entries.keys.first;
      _entries.remove(oldestKey);
      for (final l in _listeners) {
        l(oldestKey);
      }
    }
  }

  void addEvictionListener(void Function(int pageNumber) listener) {
    _listeners.add(listener);
  }

  void trimAround({required int pivot, required int keep}) {
    assert(keep > 0);
    final radius = (keep - 1) ~/ 2;
    final lo = pivot - radius;
    final hi = pivot + radius;
    final toEvict = _entries.keys
        .where((k) => k < lo || k > hi)
        .toList(growable: false);
    for (final k in toEvict) {
      _entries.remove(k);
      for (final l in _listeners) {
        l(k);
      }
    }
  }

  void clear() {
    final keys = _entries.keys.toList(growable: false);
    _entries.clear();
    for (final k in keys) {
      for (final l in _listeners) {
        l(k);
      }
    }
  }
}
