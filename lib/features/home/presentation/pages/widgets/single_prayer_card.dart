import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/constants/assets_dir.dart';

class SinglePrayerCard extends StatelessWidget {
  const SinglePrayerCard({
    super.key,
    required this.time24,
    required this.is24,
    required this.isCurrent,
  });
  final String time24;
  final bool isCurrent;
  final bool is24;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.colorScheme.secondary;
    final inactiveColor = Colors.transparent;
    final cardRadius = BorderRadius.circular(12);
    return Column(
          crossAxisAlignment: .center,
          children: [
            Text(time24),
            SvgPicture.asset(AssetsDir.iconsDir('icon_dawn.svg')),
            Text('d'),
          ],
        )
        .animate(target: isCurrent ? 1 : 0)
        .custom(
          duration: 1.seconds,
          builder: (context, value, child) => Container(
            decoration: BoxDecoration(
              color: Color.lerp(activeColor, inactiveColor, value),
              borderRadius: cardRadius,
            ),
            child: child,
          ),
        );
  }
}
