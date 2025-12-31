import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../../config/theme/typography_styles.dart';
import '../../../../../../core/constants/assets_dir.dart';

class SurahNumberStar extends StatelessWidget {
  const SurahNumberStar({super.key, required this.surahNumber});
  final int surahNumber;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SvgPicture.asset(
          AssetsDir.iconsDir('icon_star.svg'),
          colorFilter: .mode(context.colorScheme.onSurface, BlendMode.srcIn),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              surahNumber.toString(),
              style: TS.extra16.copyWith(color: context.colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}
