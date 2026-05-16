import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_model.dart';

void main() {
  test('MushafPageModel.fromJson parses page + ayahs + rects', () {
    final model = MushafPageModel.fromJson({
      'page': 2,
      'ayahs': [
        {
          'surah': 2,
          'ayah': 1,
          'lines': [
            {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.05},
          ],
        },
      ],
    });

    expect(model.pageNumber, 2);
    expect(model.ayahs, hasLength(1));
    expect(model.ayahs.first.ayah.surah, 2);
    expect(model.ayahs.first.ayah.ayah, 1);
    expect(model.ayahs.first.lines.first.x, 0.1);
    expect(model.ayahs.first.lines.first.h, 0.05);
  });

  test('MushafPageModel.fromJson handles multi-line ayahs', () {
    final model = MushafPageModel.fromJson({
      'page': 5,
      'ayahs': [
        {
          'surah': 2,
          'ayah': 30,
          'lines': [
            {'x': 0.0, 'y': 0.1, 'w': 1.0, 'h': 0.05},
            {'x': 0.0, 'y': 0.15, 'w': 0.8, 'h': 0.05},
          ],
        },
      ],
    });

    expect(model.ayahs.first.lines, hasLength(2));
  });
}
