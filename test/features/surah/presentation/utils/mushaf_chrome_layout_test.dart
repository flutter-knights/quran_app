import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_chrome_layout.dart';

void main() {
  group('resolveMushafChromeLayout', () {
    const w = 400.0;
    final pageH = w / kMushafPageAspect; // natural width-fit height (= w * 1.82)

    test('tall screen with ample slack uses bands and keeps page natural size',
        () {
      final layout = resolveMushafChromeLayout(
        availableWidth: w,
        availableHeight: pageH + 200,
      );
      expect(layout.mode, MushafChromeMode.bands);
      expect(layout.hasBands, isTrue);
      expect(layout.pageWidth, w);
      expect(layout.pageHeight, closeTo(pageH, 0.001));
      expect(layout.headerHeight, kMushafHeaderBandHeight);
      expect(layout.footerHeight, kMushafFooterBandHeight);
      expect(
        layout.pageHeight + layout.headerHeight + layout.footerHeight,
        lessThanOrEqualTo(pageH + 200),
      );
    });

    test('slack exactly equal to both bands still uses bands (boundary)', () {
      final layout = resolveMushafChromeLayout(
        availableWidth: w,
        availableHeight:
            pageH + kMushafHeaderBandHeight + kMushafFooterBandHeight,
      );
      expect(layout.mode, MushafChromeMode.bands);
    });

    test('slack just below both bands falls back to overlay', () {
      final layout = resolveMushafChromeLayout(
        availableWidth: w,
        availableHeight:
            pageH + kMushafHeaderBandHeight + kMushafFooterBandHeight - 1,
      );
      expect(layout.mode, MushafChromeMode.overlay);
      expect(layout.headerHeight, 0);
      expect(layout.footerHeight, 0);
      expect(layout.pageWidth, w);
      expect(layout.pageHeight, closeTo(pageH, 0.001));
    });

    test('screen exactly as tall as the page overlays (no slack)', () {
      final layout = resolveMushafChromeLayout(
        availableWidth: w,
        availableHeight: pageH,
      );
      expect(layout.mode, MushafChromeMode.overlay);
      expect(layout.pageWidth, w);
      expect(layout.pageHeight, closeTo(pageH, 0.001));
    });

    test('page taller than screen is fitted by height and overlays', () {
      final layout = resolveMushafChromeLayout(
        availableWidth: 800,
        availableHeight: 400,
      );
      expect(layout.mode, MushafChromeMode.overlay);
      expect(layout.pageHeight, 400);
      expect(layout.pageWidth, closeTo(400 * kMushafPageAspect, 0.001));
      expect(layout.pageWidth, lessThan(800));
    });

    test('overlay page art preserves the source aspect ratio', () {
      final layout = resolveMushafChromeLayout(
        availableWidth: 390,
        availableHeight: 390 / kMushafPageAspect,
      );
      expect(
        layout.pageWidth / layout.pageHeight,
        closeTo(kMushafPageAspect, 0.001),
      );
    });
  });
}
