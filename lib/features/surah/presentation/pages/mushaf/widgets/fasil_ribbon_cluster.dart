import 'dart:math';

import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/fasil_rules.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

enum _End { notch, point, square }

extension on FasilSlot {
  _End get end => switch (this) {
    FasilSlot.wird => _End.notch,
    FasilSlot.hifz => _End.point,
    FasilSlot.muraja => _End.square,
  };
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({
    required this.color,
    required this.stitch,
    this.end = _End.square,
    this.shadow = true,
  });

  final Color color;
  final Color stitch;
  final _End end;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, end == _End.point ? h - 8 : h);
    switch (end) {
      case _End.notch:
        path.lineTo(w / 2, h - 8);
        path.lineTo(0, h);
      case _End.point:
        path.lineTo(w / 2, h);
        path.lineTo(0, h - 8);
      case _End.square:
        path.lineTo(0, h);
    }
    path.close();
    if (shadow) {
      canvas.drawPath(
        path.shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    final line = Paint()
      ..color = stitch
      ..strokeWidth = 1;
    for (var y = 3.0; y < h - 8; y += 4) {
      canvas.drawLine(Offset(w / 2, y), Offset(w / 2, min(y + 2, h - 8)), line);
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.color != color ||
      old.stitch != stitch ||
      old.end != end ||
      old.shadow != shadow;
}

Color _stitch(MushafPaper paper) =>
    paper.colors.background.withValues(alpha: 0.45);

class FasilRibbonCluster extends StatelessWidget {
  const FasilRibbonCluster({
    super.key,
    required this.placed,
    required this.paper,
    required this.onTap,
  });

  final Map<FasilSlot, String> placed;
  final MushafPaper paper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (placed.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('fasil-cluster'));
    }
    final s = PendingS.of(context);
    final names = [
      for (final slot in FasilSlot.values)
        if (placed.containsKey(slot)) placed[slot]!,
    ];
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: s.fasil_clusterLabel(names.join('، ')),
      child: Tooltip(
        message: s.fasil_title,
        child: GestureDetector(
          key: const ValueKey('fasil-cluster'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 48,
            height: fasilClusterHeight,
            child: Stack(
              children: [
                for (final slot in placed.keys)
                  Positioned(
                    left: fasilRibbonX(slot),
                    top: 0,
                    width: 12,
                    height: 44,
                    child: CustomPaint(
                      painter: _RibbonPainter(
                        color: paper.ribbon(slot),
                        stitch: _stitch(paper),
                        end: slot.end,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FasilTailTab extends StatelessWidget {
  const FasilTailTab({
    super.key,
    required this.slot,
    required this.name,
    required this.paper,
    required this.onTap,
  });

  final FasilSlot slot;
  final String name;
  final MushafPaper paper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          key: ValueKey('fasil-tail-${slot.name}'),
          width: 48,
          height: fasilTailHeight,
          child: Stack(
            children: [
              Positioned(
                key: const ValueKey('fasil-tail-label'),
                left: max(0, fasilRibbonX(slot) + 12 - 22),
                top: 0,
                bottom: 0,
                width: 22,
                child: CustomPaint(
                  painter: _RibbonPainter(
                    color: paper.ribbon(slot),
                    stitch: Colors.transparent,
                    end: slot.end,
                  ),
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
                        child: Text(
                          name,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: TS.bold14.copyWith(
                            color: paper.colors.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FasilStrip extends StatelessWidget {
  const FasilStrip({super.key, required this.slot, required this.paper});

  final FasilSlot slot;
  final MushafPaper paper;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: ValueKey('fasil-strip-${slot.name}'),
      child: CustomPaint(
        size: Size.infinite,
        painter: _RibbonPainter(
          color: paper.ribbon(slot),
          stitch: _stitch(paper),
          shadow: false,
        ),
      ),
    );
  }
}
