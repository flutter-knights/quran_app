import 'package:flutter/widgets.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';

extension FasilSlotLocalization on FasilSlot {
  String localized(BuildContext context) {
    final s = PendingS.of(context);
    return switch (this) {
      FasilSlot.wird => s.fasil_wird,
      FasilSlot.hifz => s.fasil_hifz,
      FasilSlot.muraja => s.fasil_muraja,
    };
  }
}
