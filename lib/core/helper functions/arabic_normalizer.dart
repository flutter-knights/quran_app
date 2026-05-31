// lib/core/helper functions/arabic_normalizer.dart

/// Normalizes Arabic/Latin text for tolerant substring search:
/// strips harakat + superscript alef + Quranic annotation marks, removes
/// tatweel, unifies alef forms (أ إ آ ٱ → ا), maps ى → ي and ة → ه, drops any
/// non-word-initial alef (so the corpus's plene spelling الرحمان matches the
/// conventional الرحمن), lowercases Latin, and collapses whitespace. The same
/// transform is applied to both the query and the index. Pure Dart — no Flutter
/// imports (safe for the domain layer).
///
/// Scope: the Quran search feature. (The hadith search path has its own
/// normalizer in AhadithHelpers.cleanArabicQuery; the two are intentionally
/// separate.)
String normalizeArabic(String input) {
  final stripped = StringBuffer();
  for (final rune in input.runes) {
    // Harakat & extended Arabic combining marks (064B–065F) + superscript alef (0670): drop.
    if (rune >= 0x064B && rune <= 0x065F) continue;
    if (rune == 0x0670) continue;
    // Quranic annotation marks / small high signs (06D6–06ED): drop.
    if (rune >= 0x06D6 && rune <= 0x06ED) continue;
    // Tatweel (kashida): drop.
    if (rune == 0x0640) continue;
    switch (rune) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        stripped.writeCharCode(0x0627); // ا
        break;
      case 0x0649: // ى
        stripped.writeCharCode(0x064A); // ي
        break;
      case 0x0629: // ة
        stripped.writeCharCode(0x0647); // ه
        break;
      default:
        stripped.writeCharCode(rune);
    }
  }
  final base = stripped
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Alef-tolerant pass: keep a word-initial alef, drop every other alef.
  final out = StringBuffer();
  var atWordStart = true;
  for (final rune in base.runes) {
    if (rune == 0x20) {
      out.writeCharCode(rune);
      atWordStart = true;
      continue;
    }
    if (rune == 0x0627 && !atWordStart) {
      continue; // drop non-initial alef
    }
    out.writeCharCode(rune);
    atWordStart = false;
  }
  return out.toString();
}
