import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/features/splash/pages/widgets/slogan_animation.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  void onLoaded(BuildContext context) {
    GoRouter.of(context).pushReplacement(AppRouter.homePath);
  }

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
                  SizedBox(
                        child: Column(
                          spacing: 16,
                          children: [
                            SvgPicture.asset(
                              AssetsDir.imagesDir('mushaf.svg'),
                              colorFilter: .mode(
                                context.colorScheme.onSurface,
                                .srcIn,
                              ),
                              width: 176,
                            ),

                            Text(
                              "اَلْقُرْآنُ الْكَرِيمُ",
                              style: TypographyStyles.display32.uthmanic,
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 2.seconds, delay: .2.seconds)
                      .scale(
                        duration: 1.5.seconds,
                        begin: Offset(1.4, 1.4),
                        end: Offset(1, 1),
                        curve: Curves.decelerate,
                      ),

                  Gap(8),
                  SloganAnimation(
                    slogan: "اقْرَأْ تَعَلَّمْ احْفَظْ",
                    onLoaded: () => onLoaded(context),
                  ),
                  Gap(68),
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Image.asset(
                      AssetsDir.imagesDir('mosque.png'),
                      color: context.colorScheme.surface,
                      alignment: .bottomCenter,
                      fit: .cover,
                    ),
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
