import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/daily_hadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/books_list_view.dart';
import 'package:quran_app/generated/l10n.dart';

/// "Hadith of the Day" home section. Owns its cubit, loads on build, and
/// renders nothing while unavailable (offline first run / API error).
class DailyHadithCard extends StatelessWidget {
  const DailyHadithCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DailyHadithCubit>()..load(),
      child: const _DailyHadithCardView(),
    );
  }
}

class _DailyHadithCardView extends StatelessWidget {
  const _DailyHadithCardView();

  String _bookTitle(BuildContext context, String slug) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == slug) return b.title;
    }
    return slug;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return BlocBuilder<DailyHadithCubit, DailyHadithState>(
      builder: (context, state) {
        if (state is DailyHadithUnavailable) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            AppSectionHeader(label: S.of(context).hadith_of_the_day),
            const SizedBox(height: 10),
            if (state is DailyHadithLoading)
              Skeletonizer(
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'صحيح',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'كتاب · ٠٠٠',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'حديث تجريبي قيد التحميل لعرض حالة الهيكل العظمي للبطاقة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
              )
            else if (state is DailyHadithLoaded)
              SurfaceCard(
                onTap: () => context.push(
                  AppRouter.hadithPath,
                  extra: (hadith: state.hadith, bookSlug: state.bookSlug),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppStatusBadge(
                          color: statusColor(state.hadith.status),
                          label: statusLabel(context, state.hadith.status),
                        ),
                        Text(
                          '${_bookTitle(context, state.bookSlug)} · #${state.hadith.hadithNumber.toLocalized(context)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.hadith.arabicHadith,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TS.bold16.scheherazade.copyWith(
                        fontSize: 16,
                        color: scheme.onSurface,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
