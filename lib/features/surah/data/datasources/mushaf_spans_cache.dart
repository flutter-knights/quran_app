import 'dart:collection';

import 'package:flutter/material.dart';

import 'mushaf_page_cache.dart';

class MushafSpansCache {
  MushafSpansCache({required this.capacity, required MushafPageCache pageCache})
      : assert(capacity > 0) {
    pageCache.addEvictionListener(_onPageEvicted);
  }

  final int capacity;
  final LinkedHashMap<int, List<InlineSpan>> _entries = LinkedHashMap();

  List<InlineSpan>? get(int pageNumber) {
    final v = _entries.remove(pageNumber);
    if (v == null) return null;
    _entries[pageNumber] = v;
    return v;
  }

  void put(int pageNumber, List<InlineSpan> spans) {
    _entries.remove(pageNumber);
    _entries[pageNumber] = spans;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();

  void _onPageEvicted(int pageNumber) {
    _entries.remove(pageNumber);
  }
}
