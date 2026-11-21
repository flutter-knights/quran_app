import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';

int? resolveRunningSurah({
  required List<AyahBoundEntity> ayahs,
  AyahIdentifier? selected,
  AyahIdentifier? playing,
  int? openedSurah,
}) {
  final real = ayahs.where((b) => b.ayah.ayah > 0).toList();
  if (real.isEmpty) return null;
  bool onPage(AyahIdentifier a) {
    final ayah = a.ayah == 0 ? 1 : a.ayah;
    return real.any((b) => b.ayah.surah == a.surah && b.ayah.ayah == ayah);
  }

  if (selected != null && onPage(selected)) return selected.surah;
  if (playing != null && onPage(playing)) return playing.surah;
  if (openedSurah != null && real.any((b) => b.ayah.surah == openedSurah)) {
    return openedSurah;
  }
  final lines = <int, int>{};
  for (final b in real) {
    lines[b.ayah.surah] = (lines[b.ayah.surah] ?? 0) + b.lines.length;
  }
  return lines.entries
      .reduce(
        (a, b) =>
            b.value > a.value || (b.value == a.value && b.key < a.key) ? b : a,
      )
      .key;
}

({AyahIdentifier start, AyahIdentifier end})? pagePlaybackRange(
  List<AyahBoundEntity> ayahs,
) {
  final real = ayahs.where((b) => b.ayah.ayah > 0);
  if (real.isEmpty) return null;
  return (start: real.first.ayah, end: real.last.ayah);
}
