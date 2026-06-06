import 'package:flutter/material.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/printed_chrome_resolver.dart';

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
String _ar(int n) =>
    n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// Printed header band (surah + juz QCF glyphs) and a bottom page-number
/// ornament, drawn as part of the mushaf page. Sizes are proportional to the
/// rendered page height so they stay within the decorative band areas of the
/// page art on any screen size.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        // Header band: sits within the 6.8% top blank margin of the page image.
        // Reduced height so the text hugs the top with less dead space below.
        final headerH = (h * 0.055).clamp(24.0, 58.0);
        final surahFontSize = (h * 0.028).clamp(11.0, 24.0);
        final juzFontSize = (h * 0.028).clamp(10.0, 24.0);

        // Footer ornament: small pill centered in the 4.5% bottom band.
        // footerPaddingTop adds breathing room between the last text line and
        // the ornament; footerPaddingBottom keeps it off the very edge.
        final footerFontSize = (h * 0.014).clamp(9.0, 12.0);
        final footerPaddingBottom = (h * 0.010).clamp(4.0, 8.0);
        final hPad = (w * 0.036).clamp(8.0, 20.0);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Header band
              SizedBox(
                height: headerH,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    hPad,
                    headerH * 0.10,
                    hPad,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        data.surahGlyphName,
                        key: const ValueKey('printed-chrome-surah'),
                        style: TextStyle(
                          fontFamily: 'QCF2BSML',
                          fontSize: surahFontSize,
                          color: colors.accent,
                        ),
                      ),
                      Text(
                        data.juzGlyphName,
                        key: const ValueKey('printed-chrome-juz'),
                        style: TextStyle(
                          fontFamily: 'QCF2BSML',
                          fontSize: juzFontSize,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Bottom page-number ornament — opaque background so it stays
              // readable even when it slightly overlaps the last text line.
              Padding(
                padding: EdgeInsets.only(top: 0, bottom: footerPaddingBottom),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: h * 0.002,
                  ),
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '﴿ ${_ar(pageNumber)} ﴾',
                    key: const ValueKey('printed-chrome-page'),
                    style: TextStyle(
                      fontSize: footerFontSize,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
