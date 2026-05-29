const int kPageLimit = 100;

/// Max number of matches an Arabic in-book search returns. Kept well below
/// [kPageLimit] so an online search never fans out into a large burst of
/// per-hadith remote requests.
const int kArabicSearchResultLimit = 30;

class HadithPagination {
  static const Map<String, int> _bookHadithCounts = {
    'sahih-bukhari': 7276,
    'sahih-muslim': 7564,
    'al-tirmidhi': 3956,
    'abu-dawood': 5274,
    'ibn-e-majah': 4341,
    'sunan-nasai': 5761,
    'mishkat': 6293,
  };

  static int getTotalPages(String slug) {
    final total = _bookHadithCounts[slug] ?? 0;
    if (total == 0) return 1;

    return (total + kPageLimit - 1) ~/ kPageLimit;
  }

  /// Total hadith count for [slug], or 0 if the book is unknown.
  static int hadithCount(String slug) => _bookHadithCounts[slug] ?? 0;
}
