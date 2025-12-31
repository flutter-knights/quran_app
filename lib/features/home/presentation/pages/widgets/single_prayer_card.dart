import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/core/widgets/toggle_widget.dart';

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
    final activeColor = context.colorScheme.surfaceContainer;
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
                    Text(prayerName, style: TS.bold14.cairo),
                    SizedBox(
                      height: 24,
                      child: SvgPicture.asset(
                        iconDir,
                        alignment: .bottomCenter,
                        colorFilter: .mode(
                          context.colorScheme.onSurface,
                          .srcIn,
                        ),
                      ),
                    ),
                    ToggleWidget(
                      targetChild: Text(
                        time24.toLocalized(context),
                        style: TS.bold12
                            .copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            )
                            .cairo,
                      ),
                      defaultChild: Text(
                        time24
                            .parse24hTime()
                            .format12h(context)
                            .toLocalized(context),
                        style: TS.bold12
                            .copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            )
                            .cairo,
                      ),

                      value: is24,
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
