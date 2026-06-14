import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart';

void main() {
  group('computeSurahProgress', () {
    test('ayah > 0 is ayah-based', () {
      final p = computeSurahProgress(
        const LastRead(page: 3, ayah: AyahIdentifier(surah: 2, ayah: 5)),
      );
      expect(p.ayahBased, isTrue);
      expect(p.ayahCurrent, 5);
      expect(p.surahNumber, 2);
    });

    test('ayah == 0 (basmala) is page-based, not "ayah 0"', () {
      final p = computeSurahProgress(
        const LastRead(page: 2, ayah: AyahIdentifier(surah: 5, ayah: 0)),
      );
      expect(p.ayahBased, isFalse);
      expect(p.ayahCurrent, isNull);
      expect(p.surahNumber, 2); // resolved from page 2, NOT the ayah's surah field (5)
    });

    test('null ayah is page-based', () {
      final p = computeSurahProgress(const LastRead(page: 2));
      expect(p.ayahBased, isFalse);
      expect(p.ayahCurrent, isNull);
    });
  });
}
