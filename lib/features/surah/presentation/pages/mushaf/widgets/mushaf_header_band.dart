import 'package:flutter/material.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/printed_chrome_resolver.dart';

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
String _ar(int n) =>
    n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// Running header for a Mushaf page: the surah QCF glyph (leading) and the juz
/// QCF glyph (trailing). Fills the height it is given and centers its content,
/// so it can sit in a reserved margin band or float as overlay chrome.
class MushafHeaderBand extends StatelessWidget {
  const MushafHeaderBand({
    super.key,
    required this.pageNumber,
    required this.colors,
  });

  final int pageNumber;
  final MushafPaperColors colors;

  @override
  Widget build(BuildContext context) {
    final data = resolvePrintedChrome(pageNumber);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              data.surahGlyphName,
              key: const ValueKey('printed-chrome-surah'),
              style: TextStyle(
                fontFamily: 'QCF2BSML',
                fontSize: 22,
                color: colors.accent,
              ),
            ),
            Text(
              data.juzGlyphName,
              key: const ValueKey('printed-chrome-juz'),
              style: TextStyle(
                fontFamily: 'QCF2BSML',
                fontSize: 18,
                color: colors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom page-number ornament (`﴿ ٣ ﴾`). Centers itself within the height it
/// is given.
class MushafPageNumberOrnament extends StatelessWidget {
  const MushafPageNumberOrnament({
    super.key,
    required this.pageNumber,
    required this.colors,
  });

  final int pageNumber;
  final MushafPaperColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '﴿ ${_ar(pageNumber)} ﴾',
          key: const ValueKey('printed-chrome-page'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}
