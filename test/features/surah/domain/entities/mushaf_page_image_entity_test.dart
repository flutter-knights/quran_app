import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';

void main() {
  test('MushafPageEntity holds page number and ayah bounds', () {
    final entity = MushafPageEntity(
      pageNumber: 2,
      ayahs: const [
        AyahBoundEntity(
          ayah: AyahIdentifier(surah: 2, ayah: 1),
          lines: [NormalizedRect(x: 0.1, y: 0.2, w: 0.3, h: 0.05)],
        ),
      ],
    );

    expect(entity.pageNumber, 2);
    expect(entity.ayahs, hasLength(1));
    expect(entity.ayahs.first.ayah.surah, 2);
    expect(entity.ayahs.first.lines.first.x, 0.1);
  });
}
