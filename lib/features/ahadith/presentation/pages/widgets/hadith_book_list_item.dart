import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/circular_bullet.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/core/widgets/toggle_widget.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_book_info.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class HadithBookListItem extends StatelessWidget {
  final HadithBookInfo bookInfo;
  final VoidCallback onTap;
  const HadithBookListItem({
    super.key,
    required this.onTap,
    required this.bookInfo,
  });

  @override
  Widget build(BuildContext context) {
    void onDownload(String bookSlug) {
      context.read<DownloadBookCubit>().downloadBook(bookSlug: bookSlug);
    }

    return BlocBuilder<DownloadBookCubit, DownloadBookState>(
      builder: (context, state) {
        return PrettierTap(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: context.colorScheme.surfaceContainer,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      Text(bookInfo.title, style: TS.extra20),
                      Text(bookInfo.author, style: TS.bold16),

                      Row(
                        spacing: 4,
                        crossAxisAlignment: .center,
                        children: [
                          Text(
                            bookInfo.arabicTitle,
                            style: TS.bold12.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            overflow: .ellipsis,
                          ),
                          CircularBullet(),
                          Text(
                            '${S.current.hadith_total_label} ${bookInfo.hadithCount.toString().toLocalized(context)}',
                            style: TS.bold12.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PrettierTap(
                  onTap: () => onDownload(bookInfo.slug),
                  child: ToggleWidget(
                    value: state.isCurrentlyDownloading(bookInfo.slug),
                    targetChild: Text(
                      "${state.getBookProgress(bookInfo.slug)}%",
                      style: TS.bold12.copyWith(
                        color: context.colorScheme.primary,
                      ),
                    ),
                    defaultChild: HugeIcon(
                      icon: state.downloadedBooks.contains(bookInfo.slug)
                          ? HugeIcons.strokeRoundedTick02
                          : HugeIcons.strokeRoundedDownload01,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
