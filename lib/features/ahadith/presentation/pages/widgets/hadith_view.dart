import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
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
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_state.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_nav_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/books_list_view.dart';
import 'package:quran_app/generated/l10n.dart';

class HadithView extends StatelessWidget {
  const HadithView({super.key});

  String _bookTitle(BuildContext context, String bookSlug) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == bookSlug) return b.title;
    }
    return bookSlug;
  }

  Future<void> _onShare(
    BuildContext context,
    Hadith hadith,
    String bookSlug,
  ) async {
    final title = _bookTitle(context, bookSlug);
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

  void _onSwipe(BuildContext context, DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v == 0) return;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final nav = context.read<HadithNavCubit>();
    // Swipe toward the start edge advances; flip for RTL so the gesture follows
    // reading direction.
    final goNext = isRtl ? v > 0 : v < 0;
    if (goNext) {
      nav.goNext();
    } else {
      nav.goPrevious();
    }
  }

  /// Slide + fade between hadiths. The new one enters from the side it travels
  /// from: next from the trailing edge, previous from the leading edge (flipped
  /// in RTL). [direction]: 1 next, -1 previous, 0 initial (fade only).
  Widget _swapTransition(
    BuildContext context,
    int direction,
    Widget child,
    Animation<double> animation,
  ) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dx = direction == 0
        ? 0.0
        : (direction == 1 ? 1.0 : -1.0) * (rtl ? -1.0 : 1.0) * 0.12;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(dx, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: BlocBuilder<HadithNavCubit, HadithNavState>(
          builder: (context, navState) {
            final hadith = navState.current;
            final bookSlug = navState.bookSlug;
            final bookmark = HadithBookmark(
              bookSlug: bookSlug,
              hadithNumber: hadith.hadithNumber,
            );
            return Column(
              children: [
                AppScreenAppBar(
                  label: _bookTitle(context, bookSlug),
                  title:
                      '${S.of(context).hadith_number_label} ${hadith.hadithNumber.toLocalized(context)}',
                  trailing: IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShare08,
                    ),
                    onPressed: () => _onShare(context, hadith, bookSlug),
                  ),
                ),
                if (navState.loading)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) => _onSwipe(context, d),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) =>
                          _swapTransition(context, navState.navDirection, child,
                              animation),
                      child: SingleChildScrollView(
                        key: ValueKey(hadith.hadithNumber),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.06),
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
                          AppSectionHeader(
                            label: S.of(context).translation_label,
                          ),
                          const SizedBox(height: 10),
                          // The translation and narrator are English-only data
                          // (the API has no Arabic narrator — the Arabic isnad
                          // lives inside the Arabic text), so force LTR even in
                          // Arabic mode.
                          Text(
                            hadith.englishHadith,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: TS.regular15.copyWith(
                              color: scheme.onSurface,
                              height: 1.78,
                            ),
                          ),
                          if (hadith.englishNarrator.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: LabelledAccentCard(
                                label: S.of(context).narrator_label,
                                body: hadith.englishNarrator,
                                accentColor: scheme.secondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          ActionButtonsRow(
                            children: [
                              ActionBtn(
                                icon: HugeIcon(icon: backArrowIcon(context)),
                                label: S.of(context).previous_hadith,
                                onPressed: navState.canGoPrevious
                                    ? () =>
                                        context.read<HadithNavCubit>().goPrevious()
                                    : null,
                              ),
                              ActionBtn.primary(
                                icon: HugeIcon(
                                  icon: forwardArrowIcon(context),
                                  color: Colors.white,
                                ),
                                label: S.of(context).next_hadith,
                                iconTrailing: true,
                                onPressed: navState.canGoNext
                                    ? () =>
                                        context.read<HadithNavCubit>().goNext()
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          BlocBuilder<HadithBookmarkCubit, HadithBookmarkState>(
                            builder: (context, state) {
                              final marked = state.contains(bookmark);
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
                                        .toggle(bookmark),
                                  ),
                                  ActionBtn(
                                    icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedShare08,
                                    ),
                                    label: S.of(context).share,
                                    onPressed: () =>
                                        _onShare(context, hadith, bookSlug),
                                  ),
                                ],
                              );
                            },
                          ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
