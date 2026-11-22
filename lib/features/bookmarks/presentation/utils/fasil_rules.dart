import 'dart:math';

import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

const fasilClusterHeight = 56.0;
const fasilTailHeight = 88.0;

double fasilRibbonX(FasilSlot slot) => 4 + 14.0 * slot.index;

FasilSlot chooserPreselect({
  required Map<FasilSlot, Place> slots,
  required int page,
  required AyahIdentifier at,
}) {
  if (slots.isEmpty) return FasilSlot.wird;
  final entries = slots.entries.toList()
    ..sort((a, b) => a.value.ayah.compareTo(b.value.ayah));
  final onPage = entries.where((e) => e.value.page == page).toList();
  if (onPage.isNotEmpty) {
    final before = onPage.where((e) => e.value.ayah.compareTo(at) <= 0);
    return (before.isEmpty ? onPage.first : before.last).key;
  }
  final preceding = entries.where((e) => e.value.ayah.compareTo(at) <= 0);
  if (preceding.isNotEmpty) return preceding.last.key;
  return slots.entries
      .reduce((a, b) => b.value.updatedAt.isAfter(a.value.updatedAt) ? b : a)
      .key;
}

List<double> layoutTailTops(List<double> wanted, {required double pageHeight}) {
  final tops = [for (final w in wanted) max(w, fasilClusterHeight)];
  for (var i = 1; i < tops.length; i++) {
    tops[i] = max(tops[i], tops[i - 1] + fasilTailHeight);
  }
  if (tops.isNotEmpty) {
    tops[tops.length - 1] = min(tops.last, pageHeight - fasilTailHeight);
    for (var i = tops.length - 2; i >= 0; i--) {
      tops[i] = min(tops[i], tops[i + 1] - fasilTailHeight);
    }
  }
  return tops;
}
