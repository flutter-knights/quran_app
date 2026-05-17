import 'package:flutter/material.dart';

import '../../config/theme/color_scheme.dart';

class CircularBullet extends StatelessWidget {
  const CircularBullet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: context.colorScheme.onSurfaceVariant,
        shape: .circle,
      ),
    );
  }
}
