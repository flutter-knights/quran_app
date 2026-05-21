import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../core/di/dependency_injection.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/ayah_bound_entity.dart';
import '../../../../domain/entities/mushaf_page_entity.dart';
import '../../../../domain/usecases/get_mushaf_page.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import 'ayah_highlight_painter.dart';
import 'ayah_long_press_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MushafPageEntity>(
      future: _entityFuture,
      builder: (context, snapshot) {
        final entity = snapshot.data;
        return AspectRatio(
          aspectRatio: 1 / 1.82,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _imagePath,
                    color: Theme.of(context).colorScheme.onSurface,
                    colorBlendMode: BlendMode.srcIn,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    fit: BoxFit.fill,
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
                              highlightColor:
                                  Theme.of(context).colorScheme.secondary,
                              playingColor:
                                  Theme.of(context).colorScheme.primary,
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
                ],
              );
            },
          ),
        );
      },
    );
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
    AyahLongPressSheet.show(context, hit);
  }

  void _handleTap(BuildContext context, Offset local, BoxConstraints c,
      List<AyahBoundEntity> ayahs) {
    final hit = _hitTest(local, c, ayahs);
    final cubit = context.read<MushafCubit>();
    if (hit != null) {
      cubit.toggleHighlight(hit);
    } else if (cubit.state.highlightedAyah != null) {
      cubit.clearHighlight();
    }
  }
}
