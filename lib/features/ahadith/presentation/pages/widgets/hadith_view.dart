import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/action_buttons_row.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/arabic_quote_block.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/core/widgets/design/labelled_accent_card.dart';
import 'package:quran_app/core/widgets/design/ornament_divider.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_state.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/books_list_view.dart';
import 'package:quran_app/generated/l10n.dart';

class HadithView extends StatelessWidget {
  const HadithView({super.key, required this.hadith, required this.bookSlug});
  final Hadith hadith;
  final String bookSlug;

  HadithBookmark get _bookmark =>
      HadithBookmark(bookSlug: bookSlug, hadithNumber: hadith.hadithNumber);

  String _bookTitle(BuildContext context) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == bookSlug) return b.title;
    }
    return bookSlug;
  }

  Future<void> _onShare(BuildContext context) async {
    final title = _bookTitle(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${hadith.arabicHadith}\n\n— $title, #${hadith.hadithNumber}',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).share_failed)));
      }
    }
  }

  Future<void> _onNext(BuildContext context) async {
    final result = await sl<GetNextHadith>().call(
      bookSlug: bookSlug,
      currentHadithNumber: hadith.hadithNumber,
    );
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (next) {
        if (next == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(S.of(context).coming_soon)));
        } else {
          context.replace(
            AppRouter.hadithPath,
            extra: (hadith: next, bookSlug: bookSlug),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(
              label: _bookTitle(context),
              title:
                  '${S.of(context).hadith_number_label} ${hadith.hadithNumber.toLocalized(context)}',
              trailing: IconChip(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedShare08),
                onPressed: () => _onShare(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppStatusBadge(
                                color: statusColor(hadith.status),
                                label: statusLabel(context, hadith.status),
                              ),
                              if (hadith.chapter != null)
                                Text(
                                  '${S.of(context).chapter_label} ${hadith.chapter!.chapterNumber.toLocalized(context)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (hadith.chapter != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: scheme.onSurface.withValues(alpha: 0.06),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hadith.chapter!.chapterArabic,
                              style: TS.bold16.copyWith(
                                fontSize: 18,
                                color: scheme.secondary,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hadith.chapter!.chapterEnglish,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppSectionHeader(label: S.of(context).arabic_label),
                    const SizedBox(height: 10),
                    ArabicQuoteBlock(hadith.arabicHadith),
                    const SizedBox(height: 14),
                    const OrnamentDivider(),
                    const SizedBox(height: 14),
                    AppSectionHeader(label: S.of(context).translation_label),
                    const SizedBox(height: 10),
                    Text(
                      hadith.englishHadith,
                      style: TS.regular15.copyWith(
                        color: scheme.onSurface,
                        height: 1.78,
                      ),
                    ),
                    if (hadith.englishNarrator.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      LabelledAccentCard(
                        label: S.of(context).narrator_label,
                        body: hadith.englishNarrator,
                        accentColor: scheme.secondary,
                      ),
                    ],
                    const SizedBox(height: 14),
                    BlocBuilder<HadithBookmarkCubit, HadithBookmarkState>(
                      builder: (context, state) {
                        final marked = state.contains(_bookmark);
                        return ActionButtonsRow(
                          children: [
                            ActionBtn(
                              icon: HugeIcon(
                                icon: marked
                                    ? HugeIcons.strokeRoundedBookmark01
                                    : HugeIcons.strokeRoundedBookmark02,
                              ),
                              label: S.of(context).bookmark,
                              onPressed: () => context
                                  .read<HadithBookmarkCubit>()
                                  .toggle(_bookmark),
                            ),
                            ActionBtn(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedShare08,
                              ),
                              label: S.of(context).share,
                              onPressed: () => _onShare(context),
                            ),
                            ActionBtn.primary(
                              icon: HugeIcon(
                                icon: forwardArrowIcon(context),
                                color: Colors.white,
                              ),
                              label: S.of(context).next_hadith,
                              onPressed: () => _onNext(context),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
