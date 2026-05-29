class HadithBookmark {
  const HadithBookmark({required this.bookSlug, required this.hadithNumber});

  final String bookSlug;
  final String hadithNumber;

  String get storageKey => '$bookSlug:$hadithNumber';

  static HadithBookmark? tryParse(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    if (parts[0].isEmpty || parts[1].isEmpty) return null;
    return HadithBookmark(bookSlug: parts[0], hadithNumber: parts[1]);
  }

  @override
  bool operator ==(Object other) =>
      other is HadithBookmark &&
      other.bookSlug == bookSlug &&
      other.hadithNumber == hadithNumber;

  @override
  int get hashCode => Object.hash(bookSlug, hadithNumber);
}
