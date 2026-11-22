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

  test('fasilRibbonX spaces the ribbons 14 px apart', () {
    expect(fasilRibbonX(FasilSlot.wird), 4);
    expect(fasilRibbonX(FasilSlot.hifz), 18);
    expect(fasilRibbonX(FasilSlot.muraja), 32);
  });
}
