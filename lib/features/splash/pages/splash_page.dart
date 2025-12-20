import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/features/splash/pages/widgets/slogan_animation.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  void onLoaded(BuildContext context) {
    GoRouter.of(context).pushReplacement(AppRouter.homePath);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        AssetImage(AssetsDir.imagesDir('splash_mosque.png')),
        context,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _gradientBackground(context),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isBigWidth = constraints.maxWidth > 1024;
                final width = isBigWidth ? constraints.maxWidth : 1024.0;

                return ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                  child: Image.asset(
                    AssetsDir.imagesDir('splash_mosque.png'),
                    width: width,
                    height: width * 0.65,
                    fit: BoxFit.cover,
                    color: context.colorScheme.surface,
                    colorBlendMode: BlendMode.srcATop,
                  ),
                );
              },
            ),
          ),

          Align(
            alignment: const Alignment(0, -0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                      spacing: 16,
                      children: [
                        Image.asset(
                          AssetsDir.imagesDir('logo.png'),
                          height: 156,
                          color: context.colorScheme.onSurface,
                        ),
                        Text(
                          "اَلْقُرْآنُ الْكَرِيمُ",
                          style: TypographyStyles.display32.uthmanic,
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 2.seconds, delay: .2.seconds)
                    .scale(
                      duration: 1.5.seconds,
                      begin: const Offset(1.4, 1.4),
                      end: const Offset(1, 1),
                      curve: Curves.decelerate,
                    ),

                const Gap(8),

                SloganAnimation(
                  slogan: "اقْرَأْ تَعَلَّمْ احْفَظْ",
                  onLoaded: () => onLoaded(context),
                ),
              ],
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
