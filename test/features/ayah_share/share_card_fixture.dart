import 'dart:ui';

import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_layout.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_grid.dart';

import '../surah/mushaf_bounds_fixture.dart';

Rect headerBoxFixture(int line) {
  final band = headerBand(line);
  return Rect.fromLTRB(54, band.top + 4, 1481, band.top + 172);
}

ShareCardLayout layoutFor(int surah, int ayah) {
  final startPage = quran.getPageNumber(surah, 1);
  final startBounds = boundsOf(startPage);
  final slot = headerSlot(
    surah: surah,
    startPage: startPage,
    startPageBounds: startBounds,
  );
  final page = quran.getPageNumber(surah, ayah);
  return shareCardLayout(
    ayah: AyahIdentifier(surah: surah, ayah: ayah),
    page: page,
    pageBounds: boundsOf(page),
    startPage: startPage,
    startPageBounds: startBounds,
    header: (page: slot.page, box: headerBoxFixture(slot.line)),
  );
}
