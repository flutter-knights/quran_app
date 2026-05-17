const int kPageLimit = 100;

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
}
