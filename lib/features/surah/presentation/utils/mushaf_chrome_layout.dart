/// How the printed chrome (surah/juz header + page-number ornament) is placed
/// relative to the page art, decided per device so the chrome never collides
/// with the Quranic text.
///
/// The page images are full-bleed: continuation pages render text flush to the
/// top edge with no margin, so a header drawn *on top* of the art overlaps the
/// first line. The fix is device-adaptive:
///
/// * [MushafChromeMode.bands] — when the screen is taller than the page (there
///   is vertical letterbox slack), the chrome lives in dedicated bands inside
///   that slack, *above* and *below* the page art. The page keeps its natural
///   size, so the normalized ayah bounds (hit-testing + highlight painting)
///   stay valid and need no remapping.
/// * [MushafChromeMode.overlay] — when the page fills the height (no usable
///   slack), the chrome floats over the page and fades out with the rest of the
///   reading chrome, so it never permanently covers text.
enum MushafChromeMode { bands, overlay }

/// Page art aspect ratio expressed as width / height (1536 × 2795 ≈ 1 / 1.82),
/// matching the `AspectRatio` used by the page view.
const double kMushafPageAspect = 1 / 1.82;

/// Height reserved for the surah + juz header band (logical px).
const double kMushafHeaderBandHeight = 34;

/// Height reserved for the bottom page-number ornament band (logical px).
const double kMushafFooterBandHeight = 30;

/// Resolved placement + sizing for a single Mushaf page within the available
/// space. [pageWidth] / [pageHeight] are the natural size of the page art;
/// [headerHeight] / [footerHeight] are non-zero only in [MushafChromeMode.bands].
class MushafChromeLayout {
  const MushafChromeLayout({
    required this.mode,
    required this.pageWidth,
    required this.pageHeight,
    required this.headerHeight,
    required this.footerHeight,
  });

  final MushafChromeMode mode;
  final double pageWidth;
  final double pageHeight;
  final double headerHeight;
  final double footerHeight;

  bool get hasBands => mode == MushafChromeMode.bands;
}

/// Decides how to place the chrome for [availableWidth] × [availableHeight].
///
/// The page is fitted by width first (its natural orientation). If that fits
/// within the height *and* leaves enough slack for both bands, the chrome uses
/// dedicated bands; otherwise it overlays. When the width-fit page is taller
/// than the available height the page is instead fitted by height and the
/// chrome overlays (there is no vertical slack to spend).
MushafChromeLayout resolveMushafChromeLayout({
  required double availableWidth,
  required double availableHeight,
}) {
  // Natural (width-fit) page height. kMushafPageAspect is width/height, so
  // height = width / aspect.
  final widthFitHeight = availableWidth / kMushafPageAspect;

  if (widthFitHeight <= availableHeight) {
    final slack = availableHeight - widthFitHeight;
    if (slack >= kMushafHeaderBandHeight + kMushafFooterBandHeight) {
      // Screen is taller than the page with room for both bands: place the
      // chrome in the slack and keep the page art at its natural size.
      return MushafChromeLayout(
        mode: MushafChromeMode.bands,
        pageWidth: availableWidth,
        pageHeight: widthFitHeight,
        headerHeight: kMushafHeaderBandHeight,
        footerHeight: kMushafFooterBandHeight,
      );
    }
    // Fits by width but not enough slack for bands → overlay over a width-fit page.
    return MushafChromeLayout(
      mode: MushafChromeMode.overlay,
      pageWidth: availableWidth,
      pageHeight: widthFitHeight,
      headerHeight: 0,
      footerHeight: 0,
    );
  }

  // Page is taller than the screen per unit width → fit by height, overlay chrome.
  return MushafChromeLayout(
    mode: MushafChromeMode.overlay,
    pageWidth: availableHeight * kMushafPageAspect,
    pageHeight: availableHeight,
    headerHeight: 0,
    footerHeight: 0,
  );
}
