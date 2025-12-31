import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ToggleWidget extends StatelessWidget {
  final Widget defaultChild;
  final Widget targetChild;
  final bool value;

  const ToggleWidget({
    super.key,
    required this.defaultChild,
    required this.targetChild,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        defaultChild
            .animate(target: value ? 0 : 1)
            .fade(duration: 300.ms)
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

        targetChild
            .animate(target: value ? 1 : 0)
            .fade(duration: 300.ms)
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
      ],
    );
  }
}
