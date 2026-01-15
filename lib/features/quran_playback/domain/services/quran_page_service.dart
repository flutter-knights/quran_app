import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

abstract class QuranPageService {
  int getPageForAyah(int surah, int ayah);
  AyahIdentifier? getFirstAyahOfPage(int page);
}

class QuranPageServiceImpl implements QuranPageService {
  @override
  int getPageForAyah(int surah, int ayah) {
    return quran.getPageNumber(surah, ayah);
  }

  @override
  AyahIdentifier? getFirstAyahOfPage(int page) {
    final data = quran.getPageData(page);
    final valid = data.cast<Map>().firstWhere(
      (e) => !(e['start'] == 0 && e['end'] == 0),
      orElse: () => {},
    );

    if (valid.isEmpty) return null;

    return AyahIdentifier(surah: valid['surah'], ayah: valid['start']);
  }
}
