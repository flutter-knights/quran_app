import 'package:flutter/material.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/printed_chrome_resolver.dart';

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
String _ar(int n) =>
    n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// Printed header band (surah + juz QCF glyphs) and a bottom page-number
/// ornament, drawn as part of the mushaf page. Always visible in page mode.
class MushafPrintedChrome extends StatelessWidget {
  const MushafPrintedChrome({
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
      child: Column(
        children: [
          // Header band — sits over the accent frame already in the page art.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: SizedBox(
              height: 34,
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
          ),
          const Spacer(),
          // Bottom page-number ornament.
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
          ),
        ],
      ),
    );
  }
}
