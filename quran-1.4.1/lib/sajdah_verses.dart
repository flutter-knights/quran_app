const sajdahPositions = {
  (7, 206),
  (13, 15),
  (16, 50),
  (17, 109),
  (19, 58),
  (22, 18),
  (22, 77),
  (25, 60),
  (27, 26),
  (32, 15),
  (38, 24),
  (41, 38),
  (53, 62),
  (84, 21),
  (96, 19),
};

const sajdahVerses = SajdahVerses._();

final class SajdahVerses {
  const SajdahVerses._();

  Object? operator [](int surah) => _SurahSajdahs(surah);
}

final class _SurahSajdahs {
  const _SurahSajdahs(this.surah);

  final int surah;

  @override
  bool operator ==(Object other) =>
      other is int && sajdahPositions.contains((surah, other));

  @override
  int get hashCode => surah.hashCode;
}
