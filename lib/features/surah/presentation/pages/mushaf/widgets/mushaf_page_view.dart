import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_state.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../../config/theme/typography_styles.dart';
import '../../../../../../core/di/dependency_injection.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/ayah_bound_entity.dart';
import '../../../../domain/entities/mushaf_page_entity.dart';
import '../../../../domain/usecases/get_mushaf_page.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import '../../../utils/reader_rules.dart';
import 'ayah_highlight_painter.dart';
import 'mushaf_page_ribbon.dart';

class MushafPageView extends StatefulWidget {
  const MushafPageView({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView>
    with SingleTickerProviderStateMixin {
  late Future<MushafPageEntity> _entityFuture;
  late final AnimationController _controller;

  AyahIdentifier? _shownHighlightedAyah;
  AyahIdentifier? _shownPlayingAyah;
  AyahIdentifier? _prevHighlightedAyah;
  AyahIdentifier? _prevPlayingAyah;

  @override
  void initState() {
    super.initState();
    _entityFuture = _load();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1.0,
    );
  }

  Future<MushafPageEntity> _load() =>
      sl<GetMushafPage>()(widget.pageNumber).then(
        (e) => e.fold<MushafPageEntity>(
          (f) =>
              throw StateError('failed to load page ${widget.pageNumber}: $f'),
          (right) => right,
        ),
      );

  void _retry() {
    final cubit = context.read<MushafCubit>();
    if (widget.pageNumber == cubit.state.currentPage) cubit.reloadPageAyahs();
    setState(() {
      _entityFuture = _load();
    });
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
        if (snapshot.hasError &&
            snapshot.connectionState == ConnectionState.done) {
          final pendingS = PendingS.of(context);
          return AspectRatio(
            aspectRatio: mushafPageAspect,
            child: ColoredBox(
              color: paperColors.background,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Text(
                      pendingS.mushaf_pageLoadFailed,
                      style: TS.medium14.copyWith(color: paperColors.ink),
                    ),
                    TextButton(
                      onPressed: _retry,
                      child: Text(pendingS.mushaf_retry, style: TS.medium14),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final entity = snapshot.data;
        return AspectRatio(
          aspectRatio: mushafPageAspect,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: paperColors.background),
                  ),
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
                  if (settings.pageBrightness < 1.0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          key: const ValueKey('page-brightness-scrim'),
                          color: Colors.black.withValues(
                            alpha: 1.0 - settings.pageBrightness,
                          ),
                        ),
                      ),
                    ),
                  if (entity != null)
                    BlocBuilder<MushafCubit, MushafState>(
                      buildWhen: (a, b) =>
                          a.selectedAyah != b.selectedAyah ||
                          a.playingAyah != b.playingAyah,
                      builder: (context, state) {
                        if (state.selectedAyah != _shownHighlightedAyah ||
                            state.playingAyah != _shownPlayingAyah) {
                          _prevHighlightedAyah = _shownHighlightedAyah;
                          _prevPlayingAyah = _shownPlayingAyah;
                          _shownHighlightedAyah = state.selectedAyah;
                          _shownPlayingAyah = state.playingAyah;
                          if (_shownHighlightedAyah != null ||
                              _shownPlayingAyah != null ||
                              _prevHighlightedAyah != null ||
                              _prevPlayingAyah != null) {
                            _controller.forward(from: 0);
                          }
                        }
                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (_, _) => CustomPaint(
                            painter: AyahHighlightPainter(
                              ayahs: entity.ayahs,
                              selectedAyah: _shownHighlightedAyah,
                              prevSelectedAyah: _prevHighlightedAyah,
                              playingAyah: _shownPlayingAyah,
                              prevPlayingAyah: _prevPlayingAyah,
                              selectedColor: paperColors.accent,
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
                          constraints,
                          entity.ayahs,
                        ),
                        onLongPressStart: (details) => _handleLongPress(
                          context,
                          details.localPosition,
                          constraints,
                          entity.ayahs,
                        ),
                      ),
                    ),
                  BlocBuilder<PageBookmarkCubit, PageBookmarkState>(
                    buildWhen: (a, b) =>
                        a.contains(widget.pageNumber) !=
                        b.contains(widget.pageNumber),
                    builder: (context, pb) {
                      if (!pb.contains(widget.pageNumber)) {
                        return const SizedBox.shrink();
                      }
                      return MushafPageRibbon(
                        color: paperColors.accent,
                        onTap: () => _onRibbonTap(context),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  AyahIdentifier? _hitTest(
    Offset local,
    BoxConstraints c,
    List<AyahBoundEntity> ayahs,
  ) {
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

  void _handleLongPress(
    BuildContext context,
    Offset local,
    BoxConstraints c,
    List<AyahBoundEntity> ayahs,
  ) {
    final hit = _hitTest(local, c, ayahs);
    if (hit != null) context.read<MushafCubit>().select(hit);
  }

  void _handleTap(
    BuildContext context,
    Offset local,
    BoxConstraints c,
    List<AyahBoundEntity> ayahs,
  ) {
    final cubit = context.read<MushafCubit>();
    final hit = _hitTest(local, c, ayahs);
    hit == null ? cubit.clearSelection() : cubit.toggleSelection(hit);
  }

  void _onRibbonTap(BuildContext context) {
    final cubit = context.read<PageBookmarkCubit>();
    cubit.toggle(widget.pageNumber);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          S.of(context).pageRemovedFromBookmarks,
          style: TS.regular14,
        ),
        action: SnackBarAction(
          label: S.of(context).undo,
          onPressed: () => cubit.toggle(widget.pageNumber),
        ),
      ),
    );
  }
}
