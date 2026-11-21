import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

class KhatamMedallion extends StatelessWidget {
  const KhatamMedallion({super.key, required this.label, required this.colors});

  final String label;
  final MushafPaperColors colors;

  @override
  Widget build(BuildContext context) {
    final style = TS.bold14.copyWith(color: colors.ink);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final extent = math.max(painter.width, painter.height);
    painter.dispose();
    final side = (extent + 20).clamp(36.0, 56.0);
    return SizedBox.square(
      dimension: side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(side),
            painter: _KhatamPainter(colors.accent),
          ),
          SizedBox.square(
            dimension: side - 12,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class _KhatamPainter extends CustomPainter {
  const _KhatamPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width / math.sqrt2,
      height: size.height / math.sqrt2,
    );
    canvas.drawRect(rect, paint);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 4);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KhatamPainter oldDelegate) => oldDelegate.color != color;
}
