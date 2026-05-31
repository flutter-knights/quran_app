// lib/core/helper functions/arabic_normalizer.dart

/// Normalizes Arabic/Latin text for tolerant substring search:
/// strips harakat + superscript alef, removes tatweel, unifies alef forms
/// (أ إ آ ٱ → ا), maps ى → ي and ة → ه, lowercases Latin, and collapses
/// whitespace. Pure Dart — no Flutter imports (safe for the domain layer).
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    // Harakat / Quranic marks (064B–065F) and superscript alef (0670): drop.
    if (rune >= 0x064B && rune <= 0x065F) continue;
    if (rune == 0x0670) continue;
    // Tatweel (kashida): drop.
    if (rune == 0x0640) continue;
    switch (rune) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        buffer.writeCharCode(0x0627); // ا
        break;
      case 0x0649: // ى
        buffer.writeCharCode(0x064A); // ي
        break;
      case 0x0629: // ة
        buffer.writeCharCode(0x0647); // ه
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
