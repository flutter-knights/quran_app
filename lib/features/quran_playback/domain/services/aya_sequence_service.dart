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
}
