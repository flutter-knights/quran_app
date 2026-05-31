import 'package:quran/quran.dart' as quran;

/// Pure validation for the from→to playback range and repeat counters.
/// Rules (per the Phase 2 spec):
/// 1. from ∈ [1, verseCount]; 0/blank → 1.
/// 2. to ∈ [from, verseCount]; over last → clamp to last.
/// 3. to < from → to follows from (to = from).
/// 4. single-surah ranges (enforced by callers using one surah's count).
/// 5. repeat ∈ [1, 99]; blank/0 → 1.
/// 8. non-numeric input → null (caller keeps the last valid value).
class PlaybackRangeValidator {
  static const int maxRepeat = 99;

  static int clampFrom({required int surah, required int value}) {
    final last = quran.getVerseCount(surah);
    if (value < 1) return 1;
    if (value > last) return last;
    return value;
  }

  static int clampTo({required int surah, required int from, required int value}) {
    final last = quran.getVerseCount(surah);
    final lo = from < 1 ? 1 : from;
    if (value < lo) return lo;
    if (value > last) return last;
    return value;
  }

  static int clampRepeat(int value) {
    if (value < 1) return 1;
    if (value > maxRepeat) return maxRepeat;
    return value;
  }

  /// Parses user text (Western or Arabic-Indic digits). Returns null for
  /// blank/non-numeric so the caller can revert to the last valid value.
  static int? parseCounter(String raw) {
    final normalized = raw.split('').map((ch) {
      final code = ch.codeUnitAt(0);
      // Arabic-Indic ٠..٩ = U+0660..U+0669 → ASCII 0..9
      if (code >= 0x0660 && code <= 0x0669) {
        return String.fromCharCode(code - 0x0660 + 0x30);
      }
      return ch;
    }).join();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }
}
