import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';

class SinglePrayerCard extends StatelessWidget {
  const SinglePrayerCard({
    super.key,
    required this.time24,
    required this.is24,
    required this.isCurrent,
    required this.prayerName,
    required this.iconDir,
  });
  final String time24;
  final String prayerName;
  final String iconDir;
  final bool isCurrent;
  final bool is24;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.colorScheme.primary.withValues(alpha: 0.3);
    final inactiveColor = Colors.transparent;
    final cardRadius = BorderRadius.circular(8);
    return Expanded(
      child: AspectRatio(
        aspectRatio: 4 / 6.5,
        child:
            Column(
                  spacing: 4,
                  mainAxisAlignment: .center,
                  mainAxisSize: .min,
                  crossAxisAlignment: .center,
                  children: [
                    Text(prayerName, style: TS.medium14.cairo),
                    SizedBox(
                      height: 24,
                      child: SvgPicture.asset(
                        iconDir,
                        alignment: .bottomCenter,
                      ),
                    ),

                    Text(
                      is24
                          ? time24.toLocalized(context)
                          : time24
                                .parse24hTime()
                                .format12h(context)
                                .toLocalized(context),
                      style: TS.medium14
                          .copyWith(color: context.colorScheme.onSurfaceVariant)
                          .cairo,
                    ),
                  ],
                )
                .animate(target: isCurrent ? 1 : 0)
                .custom(
                  duration: 1.seconds,
                  builder: (context, value, child) => Container(
                    decoration: BoxDecoration(
                      color: Color.lerp(inactiveColor, activeColor, value),
                      borderRadius: cardRadius,
                    ),
                    child: child,
                  ),
                ),
      ),
    );
  }
}
