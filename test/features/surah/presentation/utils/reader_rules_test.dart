import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';

AyahIdentifier id(int s, int a) => AyahIdentifier(surah: s, ayah: a);

AyahBoundEntity bound(int s, int a, [double y = 0]) => AyahBoundEntity(
  ayah: id(s, a),
  lines: [NormalizedRect(x: 0, y: y, w: 1, h: 0.05)],
);

void main() {
  group('listenRange', () {
    test('a selected ayah listens to the end of its surah', () {
      final range = listenRange(selected: id(3, 7), ayahs: const []);
      expect(range?.start, id(3, 7));
      expect(range?.end, id(3, 200));
    });

    test('a selected banner starts at the first ayah', () {
      final range = listenRange(selected: id(5, 0), ayahs: const []);
      expect(range?.start, id(5, 1));
      expect(range?.end, id(5, 120));
    });

    test('with no selection the first real ayah on the page starts', () {
      final range = listenRange(
        ayahs: [bound(4, 176), bound(5, 0), bound(5, 1), bound(5, 2)],
      );
      expect(range?.start, id(4, 176));
      expect(range?.end, id(4, 176));
    });

    test('nothing selected and no bounds gives null', () {
      expect(listenRange(ayahs: const []), isNull);
    });
  });

  group('playbackScope', () {
    test('a range to the last ayah of a surah is surahEnd', () {
      expect(playbackScope(id(3, 7), id(3, 200)), PlaybackScope.surahEnd);
    });

    test('a range ending a page is pageEnd', () {
      expect(playbackScope(id(4, 176), id(5, 2)), PlaybackScope.pageEnd);
      expect(playbackScope(id(112, 1), id(114, 6)), PlaybackScope.pageEnd);
      expect(playbackScope(id(2, 6), id(2, 16)), PlaybackScope.pageEnd);
    });

    test('a range ending mid-page is none', () {
      expect(playbackScope(id(2, 5), id(2, 20)), PlaybackScope.none);
      expect(playbackScope(null, null), PlaybackScope.none);
    });
  });

  group('lineBottomOf', () {
    test('is the lowest line edge of the ayah', () {
      final ayahs = [
        AyahBoundEntity(
          ayah: id(2, 3),
          lines: const [
            NormalizedRect(x: 0, y: 0.40, w: 1, h: 0.05),
            NormalizedRect(x: 0, y: 0.45, w: 1, h: 0.05),
          ],
        ),
      ];
      expect(lineBottomOf(ayahs, id(2, 3)), closeTo(0.5, 1e-9));
      expect(lineBottomOf(ayahs, id(2, 4)), isNull);
      expect(lineBottomOf(ayahs, null), isNull);
    });
  });

  group('leafSlide', () {
    test('a tall area leaves the page flush at the top', () {
      const area = Size(390, 651);
      expect(leafSlide(area: area, lineBottom: 0.5, overlay: 168), 0);
      expect(
        leafSlide(area: area, lineBottom: 0.8, overlay: 168),
        closeTo(37.8, 0.01),
      );
      expect(
        leafSlide(area: area, lineBottom: 1.0, overlay: 168),
        closeTo(168, 0.01),
      );
    });

    test('a wide area centres the page', () {
      const area = Size(390, 800);
      expect(
        leafSlide(area: area, lineBottom: 0.95, overlay: 168),
        closeTo(87.35, 0.05),
      );
      expect(leafSlide(area: area, lineBottom: 0.5, overlay: 168), 0);
    });
  });

  group('readerNotice', () {
    test('a jump origin wins', () {
      expect(
        readerNotice(jumpFrom: 50, downloadHintSurah: 3, hintSeen: false),
        const ReturnToPageNotice(50),
      );
      expect(
        readerNotice(jumpFrom: 50, hintSeen: true, audioError: true),
        const ReturnToPageNotice(50),
      );
    });

    test('the download hint comes next', () {
      expect(
        readerNotice(downloadHintSurah: 3, hintSeen: false),
        const DownloadHintNotice(3),
      );
    });

    test('an audio error hides the download hint', () {
      expect(
        readerNotice(downloadHintSurah: 3, hintSeen: true, audioError: true),
        isNull,
      );
      expect(
        readerNotice(downloadHintSurah: 3, hintSeen: false, audioError: true),
        const TapHintNotice(),
      );
    });

    test('the first-open hint shows until seen', () {
      expect(readerNotice(hintSeen: false), const TapHintNotice());
      expect(readerNotice(hintSeen: true), isNull);
    });
  });
}
