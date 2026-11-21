class AyahIdentifier implements Comparable<AyahIdentifier> {
  final int surah;
  final int ayah;

  const AyahIdentifier({required this.surah, required this.ayah});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AyahIdentifier && other.surah == surah && other.ayah == ayah;

  @override
  int compareTo(AyahIdentifier other) => surah != other.surah
      ? surah.compareTo(other.surah)
      : ayah.compareTo(other.ayah);

  @override
  int get hashCode => Object.hash(surah, ayah);
}
