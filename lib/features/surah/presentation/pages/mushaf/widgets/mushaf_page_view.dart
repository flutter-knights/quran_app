import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/fasil_rules.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/place_labels.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/core/localization/pending_s.dart';

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
import 'fasil_ribbon_cluster.dart';

class MushafPageView extends StatefulWidget {
  const MushafPageView({
    super.key,
    required this.pageNumber,
    required this.onOpenFawasil,
  });

  final int pageNumber;
  final void Function(FasilSlot? slot) onOpenFawasil;

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

  String get _imagePath => AssetsDir.mushafPage(widget.pageNumber);

  // Accent layer: header frame + ayah-number rosettes, tinted separately.
  String get _accentPath => AssetsDir.mushafPageAccent(widget.pageNumber);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state.settingsModel;
    final paperColors = settings.mushafPaper.colors;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<MushafPageEntity>(
        future: _entityFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError &&
              snapshot.connectionState == ConnectionState.done) {
            final pendingS = PendingS.of(context);
            return AspectRatio(
              aspectRatio: mushafPageAspect,
              child: ColoredBox(
                color: paperColors.background,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          Text(
                            pendingS.mushaf_pageLoadFailed,
                            style: TS.medium14.copyWith(color: paperColors.ink),
                          ),
                          TextButton(
                            style: paperColors.paperButton(),
                            onPressed: _retry,
                            child: Text(
                              pendingS.mushaf_retry,
                              style: TS.medium14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FasilLayer(
                      pageNumber: widget.pageNumber,
                      entity: null,
                      paper: settings.mushafPaper,
                      onOpenFawasil: widget.onOpenFawasil,
                    ),
                  ],
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
                    if (entity != null)
                      _SavedDots(
                        pageNumber: widget.pageNumber,
                        entity: entity,
                        height: constraints.maxHeight,
                        color: paperColors.accent,
                      ),
                    _FasilLayer(
                      pageNumber: widget.pageNumber,
                      entity: entity,
                      paper: settings.mushafPaper,
                      onOpenFawasil: widget.onOpenFawasil,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
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
}

class _SavedDots extends StatelessWidget {
  const _SavedDots({
    required this.pageNumber,
    required this.entity,
    required this.height,
    required this.color,
  });

  final int pageNumber;
  final MushafPageEntity entity;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SavedAyatCubit, SavedAyatState, List<Place>>(
      selector: (s) => s.items,
      builder: (context, items) => Positioned.fill(
        child: Stack(
          children: [
            for (final place in items)
              if (place.page == pageNumber)
                if (firstLineOf(entity.ayahs, place.ayah) case final line?)
                  PositionedDirectional(
                    key: ValueKey(
                      'saved-dot-${place.ayah.surah}:${place.ayah.ayah}',
                    ),
                    start: 6,
                    top: (line.y + line.h / 2) * height - 3,
                    width: 6,
                    height: 6,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _FasilLayer extends StatelessWidget {
  const _FasilLayer({
    required this.pageNumber,
    required this.entity,
    required this.paper,
    required this.onOpenFawasil,
  });

  final int pageNumber;
  final MushafPageEntity? entity;
  final MushafPaper paper;
  final void Function(FasilSlot? slot) onOpenFawasil;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FasilCubit, FasilState, Map<FasilSlot, Place>>(
      selector: (s) => s.slots,
      builder: (context, slots) => LayoutBuilder(
        builder: (context, constraints) {
          final ayahs = entity?.ayahs;
          final geometry = FasilGeometry.forPage(
            pageWidth: constraints.maxWidth,
            textLeft: ayahs == null ? null : pageTextLeftOf(ayahs),
          );
          final tails = ayahs == null
              ? const <FasilTail>[]
              : fasilTails(
                  places: slots.values,
                  page: pageNumber,
                  pageHeight: constraints.maxHeight,
                  firstLineBottom: (ayah) => firstLineBottomOf(ayahs, ayah),
                );
          return Stack(
            children: [
              for (final tail in tails)
                PositionedDirectional(
                  end: geometry.ribbonOffset(tail.place.slot!),
                  top: 0,
                  width: geometry.ribbonWidth,
                  height: tail.top,
                  child: FasilStrip(slot: tail.place.slot!, paper: paper),
                ),
              for (final tail in tails)
                PositionedDirectional(
                  end: 0,
                  top: tail.top,
                  width: geometry.margin,
                  height: fasilTailHeight,
                  child: FasilTailTab(
                    slot: tail.place.slot!,
                    name: fasilName(context, tail.place.slot!, tail.place),
                    paper: paper,
                    geometry: geometry,
                    onTap: () => onOpenFawasil(tail.place.slot),
                  ),
                ),
              if (slots.isNotEmpty)
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  child: FasilRibbonCluster(
                    placed: {
                      for (final e in slots.entries)
                        e.key: fasilName(context, e.key, e.value),
                    },
                    paper: paper,
                    geometry: geometry,
                    onTap: () => onOpenFawasil(null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
