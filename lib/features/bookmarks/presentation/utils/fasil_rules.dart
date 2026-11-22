import 'dart:math';

import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

const fasilClusterHeight = 56.0;
const fasilTailHeight = 88.0;
const fasilDefaultTextLeft = 0.095;
const fasilMaxTextLeft = 0.11;

class FasilGeometry {
  const FasilGeometry(this.margin);

  factory FasilGeometry.forPage({
    required double pageWidth,
    double? textLeft,
  }) => FasilGeometry(
    pageWidth * (textLeft ?? fasilDefaultTextLeft).clamp(0, fasilMaxTextLeft),
  );

  final double margin;

  double get ribbonWidth => min(12, margin * 0.24);
  double get labelWidth => min(22, margin);
  double get _pitch => min(14, margin * 0.3);
  double get _inset => min(4, margin * 0.04);

  double ribbonOffset(FasilSlot slot) => _inset + _pitch * slot.index;

  double labelOffset(FasilSlot slot) =>
      max(0, ribbonOffset(slot) + ribbonWidth - labelWidth);
}

typedef FasilTail = ({Place place, double top});

FasilSlot chooserPreselect({
  required Map<FasilSlot, Place> slots,
  required int page,
  required AyahIdentifier at,
}) {
  if (slots.isEmpty) return FasilSlot.wird;
  final entries = slots.entries.toList()
    ..sort((a, b) {
      final byAyah = a.value.ayah.compareTo(b.value.ayah);
      return byAyah != 0 ? byAyah : a.key.index.compareTo(b.key.index);
    });
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

List<FasilTail> fasilTails({
  required Iterable<Place> places,
  required int page,
  required double pageHeight,
  required double? Function(AyahIdentifier ayah) firstLineBottom,
}) {
  final wanted =
      [
        for (final place in places)
          if (place.page == page)
            if (firstLineBottom(place.ayah) case final bottom?)
              (place: place, top: bottom * pageHeight - fasilTailHeight),
      ]..sort((a, b) {
        final byTop = a.top.compareTo(b.top);
        return byTop != 0
            ? byTop
            : a.place.slot!.index.compareTo(b.place.slot!.index);
      });
  final tops = layoutTailTops([
    for (final w in wanted) w.top,
  ], pageHeight: pageHeight);
  return [for (final (i, w) in wanted.indexed) (place: w.place, top: tops[i])];
}
