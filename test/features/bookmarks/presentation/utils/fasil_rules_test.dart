import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/fasil_rules.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

Place place(FasilSlot slot, int surah, int ayah, {int day = 1}) => Place(
  id: slot.name,
  ayah: AyahIdentifier(surah: surah, ayah: ayah),
  page: quran.getPageNumber(surah, ayah),
  slot: slot,
  createdAt: DateTime(2026, 1, day),
  updatedAt: DateTime(2026, 1, day),
);

AyahIdentifier at(int surah, int ayah) =>
    AyahIdentifier(surah: surah, ayah: ayah);

void main() {
  group('chooserPreselect', () {
    test('the slot on this page wins', () {
      final slots = {
        FasilSlot.hifz: place(FasilSlot.hifz, 3, 6),
        FasilSlot.wird: place(FasilSlot.wird, 2, 5),
      };
      expect(
        chooserPreselect(slots: slots, page: 50, at: at(3, 10)),
        FasilSlot.hifz,
      );
    });

    test('two on this page: the last at or before the ayah', () {
      final slots = {
        FasilSlot.wird: place(FasilSlot.wird, 3, 4),
        FasilSlot.hifz: place(FasilSlot.hifz, 3, 6),
      };
      expect(
        chooserPreselect(slots: slots, page: 50, at: at(3, 5)),
        FasilSlot.wird,
      );
      expect(
        chooserPreselect(slots: slots, page: 50, at: at(3, 7)),
        FasilSlot.hifz,
      );
      expect(
        chooserPreselect(slots: slots, page: 50, at: at(3, 2)),
        FasilSlot.wird,
      );
    });

    test('two on one ayah: the later slot wins whatever the map order', () {
      final wirdFirst = {
        FasilSlot.wird: place(FasilSlot.wird, 3, 6),
        FasilSlot.hifz: place(FasilSlot.hifz, 3, 6),
      };
      final hifzFirst = {
        FasilSlot.hifz: place(FasilSlot.hifz, 3, 6),
        FasilSlot.wird: place(FasilSlot.wird, 3, 6),
      };
      for (final slots in [wirdFirst, hifzFirst]) {
        expect(
          chooserPreselect(slots: slots, page: 50, at: at(3, 10)),
          FasilSlot.hifz,
        );
      }
    });

    test('a slot already on the ayah is skipped', () {
      final slots = {
        FasilSlot.wird: place(FasilSlot.wird, 3, 4),
        FasilSlot.hifz: place(FasilSlot.hifz, 3, 6),
      };
      expect(
        chooserPreselect(slots: slots, page: 50, at: at(3, 6)),
        FasilSlot.wird,
      );
      expect(
        chooserPreselect(
          slots: {FasilSlot.hifz: place(FasilSlot.hifz, 3, 6)},
          page: 50,
          at: at(3, 6),
        ),
        FasilSlot.wird,
      );
    });

    test('else the nearest preceding', () {
      final slots = {
        FasilSlot.wird: place(FasilSlot.wird, 2, 5),
        FasilSlot.hifz: place(FasilSlot.hifz, 2, 102),
      };
      expect(
        chooserPreselect(slots: slots, page: 50, at: at(3, 7)),
        FasilSlot.hifz,
      );
    });

    test('else the last used', () {
      final slots = {
        FasilSlot.wird: place(FasilSlot.wird, 5, 1),
        FasilSlot.hifz: place(FasilSlot.hifz, 10, 1, day: 2),
      };
      expect(
        chooserPreselect(slots: slots, page: 2, at: at(2, 5)),
        FasilSlot.hifz,
      );
    });

    test('nothing placed gives wird', () {
      expect(
        chooserPreselect(slots: const {}, page: 2, at: at(2, 5)),
        FasilSlot.wird,
      );
    });
  });

  group('layoutTailTops', () {
    test('a lone tab keeps its place', () {
      expect(layoutTailTops([200], pageHeight: 700), [200]);
    });

    test('a tab stays below the cluster', () {
      expect(layoutTailTops([10], pageHeight: 700), [56]);
    });

    test('tabs on one line stack', () {
      expect(layoutTailTops([200, 200], pageHeight: 700), [200, 288]);
      expect(layoutTailTops([200, 230, 250], pageHeight: 700), [200, 288, 376]);
    });

    test('the stack is pushed up from the page bottom', () {
      expect(layoutTailTops([650, 650], pageHeight: 700), [524, 612]);
    });
  });

  group('FasilGeometry', () {
    test('at 40 px the ribbons fit the margin, 12 px apart', () {
      const g = FasilGeometry(40);
      expect(g.ribbonWidth, closeTo(9.6, 0.001));
      expect(g.ribbonOffset(FasilSlot.wird), closeTo(1.6, 0.001));
      expect(g.ribbonOffset(FasilSlot.hifz), closeTo(13.6, 0.001));
      expect(g.ribbonOffset(FasilSlot.muraja), closeTo(25.6, 0.001));
    });

    test('a wide margin caps at 12 px ribbons 14 px apart', () {
      const g = FasilGeometry(100);
      expect(g.ribbonWidth, 12);
      expect(g.labelWidth, 22);
      expect(g.ribbonOffset(FasilSlot.wird), 4);
      expect(g.ribbonOffset(FasilSlot.hifz), 18);
      expect(g.ribbonOffset(FasilSlot.muraja), 32);
    });

    test('everything stays inside the margin on any page width', () {
      for (final width in [240.0, 320.0, 360.0, 412.0, 600.0, 1000.0]) {
        for (final textLeft in [null, 0.0733, 0.1, 0.2]) {
          final g = FasilGeometry.forPage(pageWidth: width, textLeft: textLeft);
          expect(g.margin, lessThanOrEqualTo(width * fasilMaxTextLeft));
          for (final slot in FasilSlot.values) {
            expect(
              g.ribbonOffset(slot) + g.ribbonWidth,
              lessThanOrEqualTo(g.margin),
            );
            expect(
              g.labelOffset(slot) + g.labelWidth,
              lessThanOrEqualTo(g.margin),
            );
          }
        }
      }
    });

    test('the margin follows the page text edge, with a default', () {
      expect(
        FasilGeometry.forPage(pageWidth: 360, textLeft: 0.08).margin,
        closeTo(28.8, 0.001),
      );
      expect(
        FasilGeometry.forPage(pageWidth: 360).margin,
        closeTo(360 * fasilDefaultTextLeft, 0.001),
      );
      expect(
        FasilGeometry.forPage(pageWidth: 360, textLeft: 0.3).margin,
        closeTo(360 * fasilMaxTextLeft, 0.001),
      );
    });
  });

  group('fasilTails', () {
    Place at(FasilSlot slot, int surah, int ayah, int page) => Place(
      id: '${slot.name}$ayah',
      ayah: AyahIdentifier(surah: surah, ayah: ayah),
      page: page,
      slot: slot,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    double? bottomOf(AyahIdentifier a) => switch (a.ayah) {
      1 => 0.10,
      2 => 0.50,
      _ => null,
    };

    test('keeps only this page and ayat that have a line', () {
      final tails = fasilTails(
        places: [
          at(FasilSlot.wird, 2, 1, 2),
          at(FasilSlot.hifz, 2, 2, 3),
          at(FasilSlot.muraja, 2, 9, 2),
        ],
        page: 2,
        pageHeight: 1000,
        firstLineBottom: bottomOf,
      );
      expect(tails.map((t) => t.place.slot), [FasilSlot.wird]);
    });

    test(
      'hangs each tail so it ends at the line bottom, below the cluster',
      () {
        final tails = fasilTails(
          places: [at(FasilSlot.wird, 2, 2, 2), at(FasilSlot.hifz, 2, 1, 2)],
          page: 2,
          pageHeight: 1000,
          firstLineBottom: bottomOf,
        );
        expect(tails.map((t) => t.place.slot), [
          FasilSlot.hifz,
          FasilSlot.wird,
        ]);
        expect(tails[0].top, fasilClusterHeight);
        expect(tails[1].top, 500 - fasilTailHeight);
      },
    );

    test('two tails on one ayah stack in slot order', () {
      final tails = fasilTails(
        places: [at(FasilSlot.hifz, 2, 2, 2), at(FasilSlot.wird, 2, 2, 2)],
        page: 2,
        pageHeight: 1000,
        firstLineBottom: bottomOf,
      );
      expect(tails.map((t) => t.place.slot), [FasilSlot.wird, FasilSlot.hifz]);
      expect(tails[1].top, tails[0].top + fasilTailHeight);
    });

    test('nothing placed gives no tails', () {
      expect(
        fasilTails(
          places: const [],
          page: 2,
          pageHeight: 1000,
          firstLineBottom: bottomOf,
        ),
        isEmpty,
      );
    });
  });
}
