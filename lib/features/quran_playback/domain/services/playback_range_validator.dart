import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';

/// Pure validation for the from→to playback range and repeat counters.
/// Rules (per the Phase 2 spec):
/// 1. from ∈ [1, verseCount]; 0/blank → 1.
/// 2. to ∈ [from, verseCount]; over last → clamp to last.
/// 3. to < from → to follows from (to = from).
/// 4. single-surah ranges (enforced by callers using one surah's count).
/// 5. repeat ∈ [1, 99]; blank/0 → 1.
/// 6–7. handled in the UI layer (Task 5).
/// 8. non-numeric input → null (caller keeps the last valid value).
class PlaybackRangeValidator {
  static const int maxRepeat = 99;

  static int clampFrom({required int surah, required int value}) {
    final last = quran.getVerseCount(surah);
    if (value < 1) return 1;
    if (value > last) return last;
    return value;
  }

  static int clampTo({
    required int surah,
    required int from,
    required int value,
  }) {
    final last = quran.getVerseCount(surah);
    final lo = from.clamp(1, last);
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
    final n = toAsciiDigits(raw);
    return n.isEmpty ? null : int.tryParse(n);
  }
}
