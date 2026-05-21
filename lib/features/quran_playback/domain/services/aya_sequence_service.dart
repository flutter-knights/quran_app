import 'package:quran/quran.dart';

import '../entities/ayah_identifier.dart';

class AyahSequenceService {
  AyahIdentifier? getNextAyah({
    required AyahIdentifier current,
    int? endSurah,
    int? endAyah,
  }) {
    final lastAyahInSurah = getVerseCount(current.surah);

    if (endSurah != null &&
        current.surah == endSurah &&
        current.ayah == endAyah) {
      return null;
    }

    if (current.ayah < lastAyahInSurah) {
      return AyahIdentifier(surah: current.surah, ayah: current.ayah + 1);
    }

    if (current.surah < 114) {
      return AyahIdentifier(surah: current.surah + 1, ayah: 1);
    }

    return null;
  }

  List<AyahIdentifier> getNextAyahs({
    required AyahIdentifier current,
    required int count,
    int? endSurah,
    int? endAyah,
  }) {
    final List<AyahIdentifier> ayahs = [];
    AyahIdentifier? temp = current;

    for (int i = 0; i < count; i++) {
      temp = getNextAyah(current: temp!, endSurah: endSurah, endAyah: endAyah);

      if (temp == null) break;
      ayahs.add(temp);
    }

    return ayahs;
  }

  AyahIdentifier? getPreviousAyah({required AyahIdentifier current}) {
    if (current.ayah > 1) {
      return AyahIdentifier(surah: current.surah, ayah: current.ayah - 1);
    }
    if (current.surah > 1) {
      final prevSurah = current.surah - 1;
      return AyahIdentifier(surah: prevSurah, ayah: getVerseCount(prevSurah));
    }
    return null;
  }
}
