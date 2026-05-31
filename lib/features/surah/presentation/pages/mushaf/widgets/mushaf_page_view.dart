import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

import '../../../../../../core/di/dependency_injection.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/ayah_bound_entity.dart';
import '../../../../domain/entities/mushaf_page_entity.dart';
import '../../../../domain/usecases/get_mushaf_page.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import '../../../utils/mushaf_chrome_layout.dart';
import 'ayah_action_popover.dart';
import 'ayah_highlight_painter.dart';
import 'mushaf_header_band.dart';

class MushafPageView extends StatefulWidget {
  const MushafPageView({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView>
    with SingleTickerProviderStateMixin {
  late final Future<MushafPageEntity> _entityFuture;
  late final AnimationController _controller;

  AyahIdentifier? _shownHighlightedAyah;
  AyahIdentifier? _shownPlayingAyah;
  AyahIdentifier? _prevHighlightedAyah;
  AyahIdentifier? _prevPlayingAyah;

  @override
  void initState() {
    super.initState();
    _entityFuture = sl<GetMushafPage>()(widget.pageNumber).then((e) {
      return e.fold<MushafPageEntity>(
        (f) => throw StateError(
            'failed to load page ${widget.pageNumber}: $f'),
        (right) => right,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _imagePath =>
      'assets/mushaf/pages/page_${widget.pageNumber.toString().padLeft(3, '0')}.png';

  // Accent layer: header frame + ayah-number rosettes, tinted separately.
  String get _accentPath =>
      'assets/mushaf/pages/page_${widget.pageNumber.toString().padLeft(3, '0')}_accent.png';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state.settingsModel;
    final paperColors = settings.mushafPaper.colors;
    return FutureBuilder<MushafPageEntity>(
      future: _entityFuture,
      builder: (context, snapshot) {
        final entity = snapshot.data;
        return ColoredBox(
          color: paperColors.background,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = resolveMushafChromeLayout(
                availableWidth: constraints.maxWidth,
                availableHeight: constraints.maxHeight,
              );
              final pageSize = Size(layout.pageWidth, layout.pageHeight);
              final page = _buildPage(
                context,
                entity,
                paperColors,
                settings.pageBrightness,
                pageSize,
              );

              // Tall screens get dedicated header/footer bands in the
              // letterbox slack — the page art keeps its natural size, so the
              // ayah bounds (hit-test + highlight) stay valid untouched.
              if (layout.hasBands) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: layout.pageWidth,
                        height: layout.headerHeight,
                        child: MushafHeaderBand(
                          pageNumber: widget.pageNumber,
                          colors: paperColors,
                        ),
                      ),
                      page,
                      SizedBox(
                        width: layout.pageWidth,
                        height: layout.footerHeight,
                        child: MushafPageNumberOrnament(
                          pageNumber: widget.pageNumber,
                          colors: paperColors,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // No slack: the page fills the height, so chrome floats over it
              // and fades out with the reading chrome (never covers text while
              // reading).
              return Center(
                child: SizedBox.fromSize(
                  size: pageSize,
                  child: Stack(
                    children: [
                      page,
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _FadingChrome(
                          child: _OverlayHeader(
                            pageNumber: widget.pageNumber,
                            colors: paperColors,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: _FadingChrome(
                          child: MushafPageNumberOrnament(
                            pageNumber: widget.pageNumber,
                            colors: paperColors,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The page art layers (background, glyphs, accent, brightness scrim,
  /// highlight painter, gesture handler) at a fixed [size]. The ayah bounds are
  /// normalized to this box, so hit-testing and highlight painting use
  /// [size]-tight constraints.
  Widget _buildPage(
    BuildContext context,
    MushafPageEntity? entity,
    MushafPaperColors paperColors,
    double pageBrightness,
    Size size,
  ) {
    final pageConstraints = BoxConstraints.tight(size);
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: ColoredBox(color: paperColors.background)),
          Image.asset(
            _imagePath,
            color: paperColors.ink,
            colorBlendMode: BlendMode.srcIn,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            fit: BoxFit.fill,
          ),
          Image.asset(
            _accentPath,
            color: paperColors.accent,
            colorBlendMode: BlendMode.srcIn,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            fit: BoxFit.fill,
          ),
          if (pageBrightness < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  key: const ValueKey('page-brightness-scrim'),
                  color: Colors.black.withValues(
                    alpha: 1.0 - pageBrightness,
                  ),
                ),
              ),
            ),
          if (entity != null)
            BlocBuilder<MushafCubit, MushafState>(
              buildWhen: (a, b) =>
                  a.highlightedAyah != b.highlightedAyah ||
                  a.playingAyah != b.playingAyah,
              builder: (context, state) {
                if (state.highlightedAyah != _shownHighlightedAyah ||
                    state.playingAyah != _shownPlayingAyah) {
                  _prevHighlightedAyah = _shownHighlightedAyah;
                  _prevPlayingAyah = _shownPlayingAyah;
                  _shownHighlightedAyah = state.highlightedAyah;
                  _shownPlayingAyah = state.playingAyah;
                  if (_shownHighlightedAyah != null ||
                      _shownPlayingAyah != null ||
                      _prevHighlightedAyah != null ||
                      _prevPlayingAyah != null) {
                    _controller.forward(from: 0);
                  }
                  _publishHighlightBounds(
                      context, _shownHighlightedAyah, entity.ayahs);
                }
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) => CustomPaint(
                    painter: AyahHighlightPainter(
                      ayahs: entity.ayahs,
                      highlightedAyah: _shownHighlightedAyah,
                      prevHighlightedAyah: _prevHighlightedAyah,
                      playingAyah: _shownPlayingAyah,
                      prevPlayingAyah: _prevPlayingAyah,
                      highlightColor: paperColors.accent,
                      playingColor: paperColors.ink,
                      animationValue: _controller.value,
                    ),
                  ),
                );
              },
            ),
          if (entity != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleTap(
                  context,
                  details.localPosition,
                  pageConstraints,
                  entity.ayahs,
                ),
                onLongPressStart: (details) => _handleLongPress(
                  context,
                  details.localPosition,
                  pageConstraints,
                  entity.ayahs,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _publishHighlightBounds(BuildContext context,
      AyahIdentifier? ayah, List<AyahBoundEntity> ayahs) {
    if (ayah == null) return;
    AyahBoundEntity? bound;
    for (final b in ayahs) {
      if (b.ayah == ayah) {
        bound = b;
        break;
      }
    }
    if (bound == null || bound.lines.isEmpty) return;
    final first = bound.lines.first;
    final centerY = first.y + first.h / 2;
    final cubit = context.read<MushafCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      cubit.setHighlightBounds(centerY);
    });
  }

  AyahIdentifier? _hitTest(
      Offset local, BoxConstraints c, List<AyahBoundEntity> ayahs) {
    final nx = local.dx / c.maxWidth;
    final ny = local.dy / c.maxHeight;
    for (final bound in ayahs) {
      for (final r in bound.lines) {
        if (nx >= r.x && nx <= r.x + r.w && ny >= r.y && ny <= r.y + r.h) {
          return bound.ayah;
        }
      }
    }
    return null;
  }

  void _handleLongPress(BuildContext context, Offset local, BoxConstraints c,
      List<AyahBoundEntity> ayahs) {
    final hit = _hitTest(local, c, ayahs);
    if (hit == null) return;

    // Find the ayah's bound entity to compute an anchor rect.
    AyahBoundEntity? bound;
    for (final b in ayahs) {
      if (b.ayah == hit) {
        bound = b;
        break;
      }
    }
    if (bound == null || bound.lines.isEmpty) return;

    final line = bound.lines.first;

    // Convert the normalized first-line rect to global coordinates.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localTopLeft = Offset(line.x * c.maxWidth, line.y * c.maxHeight);
    final localBottomRight = Offset(
      (line.x + line.w) * c.maxWidth,
      (line.y + line.h) * c.maxHeight,
    );
    final globalTopLeft = box.localToGlobal(localTopLeft);
    final globalBottomRight = box.localToGlobal(localBottomRight);
    final anchorGlobal = Rect.fromPoints(globalTopLeft, globalBottomRight);

    final placement = popoverPlacement(verseCenterY: line.y + line.h / 2);

    AyahActionPopover.show(
      context,
      hit,
      anchorGlobal: anchorGlobal,
      placement: placement,
    );
  }

  void _handleTap(BuildContext context, Offset local, BoxConstraints c,
      List<AyahBoundEntity> ayahs) {
    final cubit = context.read<MushafCubit>();
    if (!cubit.state.chromeVisible) {
      cubit.setChrome(true);
      return;
    }
    final hit = _hitTest(local, c, ayahs);
    if (hit != null) {
      cubit.toggleHighlight(hit); // opens the playback overlay via existing plumbing
    } else {
      cubit.setChrome(false);
    }
  }
}

/// Wraps overlay chrome so it follows the reading-chrome visibility: it fades
/// out while reading (so it never permanently covers the page text) and is
/// always click-through (taps fall to the page's gesture handler).
class _FadingChrome extends StatelessWidget {
  const _FadingChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) => a.chromeVisible != b.chromeVisible,
      builder: (context, state) => IgnorePointer(
        child: AnimatedOpacity(
          opacity: state.chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }
}

/// The running header drawn over a full-bleed page (overlay mode): a slim
/// translucent strip behind the surah/juz glyphs so they stay legible above
/// the text underneath.
class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({required this.pageNumber, required this.colors});

  final int pageNumber;
  final MushafPaperColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kMushafHeaderBandHeight,
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.82),
        border: Border(
          bottom: BorderSide(color: colors.accent.withValues(alpha: 0.25)),
        ),
      ),
      child: MushafHeaderBand(pageNumber: pageNumber, colors: colors),
    );
  }
}
