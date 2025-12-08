import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/features/splash/pages/widgets/slogan_animation.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _gradientBackground(context),
          Align(
            alignment: .center,
            child: SizedBox(
              child: Column(
                mainAxisAlignment: .end,
                children: [
                  SvgPicture.asset(
                    AssetsDir.imagesDir('mushaf.svg'),
                    colorFilter: .mode(context.colorScheme.onSurface, .srcIn),
                    width: 176,
                  ).animate().scaleX(
                    duration: 2.seconds,
                    curve: Curves.elasticOut,
                  ),
                  Gap(16),
                  Text(
                        "اَلْقُرْآنُ الْكَرِيمُ",
                        style: TypographyStyles.display32.uthmanic,
                      )
                      .animate()
                      .fadeIn(duration: 2.seconds, delay: .2.seconds)
                      .scale(duration: .2.seconds),
                  Gap(8),
                  SloganAnimation(slogan: "اقْرَأْ تَعَلَّمْ احْفَظْ"),
                  Gap(48),
                  SvgPicture.asset(
                    AssetsDir.imagesDir('mosque.svg'),
                    colorFilter: .mode(context.colorScheme.surface, .srcIn),
                    alignment: .bottomCenter,
                    fit: .cover,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Container _gradientBackground(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: .topCenter,
        end: .bottomCenter,
        colors: [context.colorScheme.surface, context.colorScheme.primary],
      ),
    ),
  );
}
