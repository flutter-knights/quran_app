import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PrettierTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double shrinkPixels;

  const PrettierTap({
    super.key,
    required this.child,
    this.onTap,
    this.shrinkPixels = 5.0,
  });

  @override
  State<PrettierTap> createState() => _PrettierTapState();
}

class _PrettierTapState extends State<PrettierTap> {
  bool _isPressed = false;
  double _smartScale = 0.95;
  final GlobalKey _key = GlobalKey();

  void _calculateScale() {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final width = renderBox.size.width;
      if (width > 0) {
        setState(() {
          _smartScale = (width - widget.shrinkPixels) / width;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateScale());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        Future.delayed(80.ms, () {
          if (mounted) setState(() => _isPressed = false);
        });
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        key: _key,
        color: Colors.transparent,
        child: widget.child
            .animate(target: _isPressed ? 1 : 0)
            .scale(
              end: Offset(_smartScale, _smartScale),
              duration: 120.ms,
              curve: Curves.easeOutCubic,
            )
            .fade(end: 0.85, duration: 120.ms),
      ),
    );
  }
}
