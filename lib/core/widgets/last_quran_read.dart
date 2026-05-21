import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../config/router/app_router.dart';
import '../../config/theme/color_scheme.dart';
import '../../config/theme/typography_styles.dart';
import '../../features/surah/domain/entities/last_read.dart';
import '../../features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import '../../generated/l10n.dart';
import '../constants/assets_dir.dart';
import '../helper functions/locale_helpers.dart';
import '../widgets/prettier_tap.dart';

class LastQuranRead extends StatelessWidget {
  const LastQuranRead({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LastReadCubit, LastRead?>(
      builder: (context, last) {
        return AspectRatio(
          aspectRatio: 2.9,
          child: Container(
            padding: EdgeInsets.only(
              left: context.isArabic ? 6 : 12,
              right: !context.isArabic ? 6 : 12,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection:
                      context.isArabic ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Text(
                      S.of(context).continue_reading,
                      style: TS.bold20,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      _subtitle(context, last),
                      style: TS.bold16.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(12),
                    PrettierTap(
                      onTap: last == null
                          ? null
                          : () => GoRouter.of(context).push(
                                AppRouter.mushafPath,
                                extra: last.page,
                              ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Text(
                          S.of(context).continue_reading,
                          style: TS.bold16.copyWith(
                            color: context.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Image.asset(
                  AssetsDir.iconsDir('quran_icon.png'),
                  color: context.colorScheme.onSurface,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitle(BuildContext context, LastRead? last) {
    if (last == null) return S.of(context).page_label('1');
    final ayah = last.ayah;
    if (ayah != null) {
      return S.of(context).ayah_label(
            ayah.surah.toString(),
            ayah.ayah.toString(),
          );
    }
    return S.of(context).page_label(last.page.toString());
  }
}
