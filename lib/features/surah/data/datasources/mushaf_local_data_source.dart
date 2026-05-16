import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/mushaf_page_model.dart';

class MushafLocalDataSource {
  MushafLocalDataSource();

  final Map<int, MushafPageModel> _cache = {};

  Future<MushafPageModel> getPage(int pageNumber) async {
    final cached = _cache[pageNumber];
    if (cached != null) return cached;

    final path =
        'assets/mushaf/bounds/page_${pageNumber.toString().padLeft(3, '0')}.json';
    final raw = await rootBundle.loadString(path);
    final model = MushafPageModel.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache[pageNumber] = model;
    return model;
  }
}
