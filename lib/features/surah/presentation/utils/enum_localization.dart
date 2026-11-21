import 'package:flutter/widgets.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/localization/pending_s.dart';

extension MushafPaperLocalization on MushafPaper {
  String localized(BuildContext context) {
    final s = PendingS.of(context);
    return switch (this) {
      MushafPaper.cream => s.mushaf_paper_cream,
      MushafPaper.sepia => s.mushaf_paper_sepia,
      MushafPaper.green => s.mushaf_paper_green,
      MushafPaper.gray => s.mushaf_paper_gray,
      MushafPaper.night => s.mushaf_paper_night,
      MushafPaper.slateNight => s.mushaf_paper_slateNight,
    };
  }
}
