import 'dart:convert';
import 'dart:io';

import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/surah/data/models/mushaf_page_model.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';

final _cache = <int, List<AyahBoundEntity>>{};

List<AyahBoundEntity> boundsOf(int page) => _cache.putIfAbsent(
  page,
  () => MushafPageModel.fromJson(
    jsonDecode(
      File(
        'assets/mushaf/bounds/page_${page.toString().padLeft(3, '0')}.json',
      ).readAsStringSync(),
    ),
  ).ayahs,
);

List<NormalizedRect> pageRectsOf(int page) => [
  for (final entry in boundsOf(page)) ...entry.lines,
];

List<NormalizedRect> linesOf(int surah, int ayah) => [
  for (final entry in boundsOf(quran.getPageNumber(surah, ayah)))
    if (entry.ayah.surah == surah && entry.ayah.ayah == ayah) ...entry.lines,
];
