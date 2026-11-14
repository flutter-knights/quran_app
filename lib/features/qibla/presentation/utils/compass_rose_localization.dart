import 'package:flutter/widgets.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/generated/l10n.dart';

extension CompassRoseL10n on CompassRose {
  String localized(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case CompassRose.n:  return s.compass_rose_n;
      case CompassRose.ne: return s.compass_rose_ne;
      case CompassRose.e:  return s.compass_rose_e;
      case CompassRose.se: return s.compass_rose_se;
      case CompassRose.s:  return s.compass_rose_s;
      case CompassRose.sw: return s.compass_rose_sw;
      case CompassRose.w:  return s.compass_rose_w;
      case CompassRose.nw: return s.compass_rose_nw;
    }
  }
}

/// Renders an int using Arabic-Indic digits when the locale is Arabic, mirroring
/// the convention in mushaf_top_bar.dart.
String localizeDigits(BuildContext context, int n) {
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final s = n.toString();
  if (!isAr) return s;
  return s.split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : arabic[d];
  }).join();
}
