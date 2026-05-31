import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart';

void main() {
  test('ayah-based progress uses verse count of the surah', () {
    // Al-Baqarah (2) has 286 ayahs; ayah 143 ≈ 50%.
    final p = computeSurahProgress(
      const LastRead(page: 22, ayah: AyahIdentifier(surah: 2, ayah: 143)),
    );
    expect(p.surahNumber, 2);
    expect(p.ayahBased, isTrue);
    expect(p.ayahCurrent, 143);
    expect(p.ayahTotal, 286);
    expect(p.fraction, closeTo(143 / 286, 0.0001));
    expect(p.surahArabicName, isNotEmpty);
  });

  test('page-only progress derives the surah from the page', () {
    // Page 1 is Al-Fatiha (surah 1).
    final p = computeSurahProgress(const LastRead(page: 1));
    expect(p.surahNumber, 1);
    expect(p.ayahBased, isFalse);
    expect(p.fraction, inInclusiveRange(0.0, 1.0));
  });
}
