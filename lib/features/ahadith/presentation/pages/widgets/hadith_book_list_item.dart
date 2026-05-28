import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_book_info.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class HadithBookListItem extends StatelessWidget {
  const HadithBookListItem({
    super.key,
    required this.onTap,
    required this.bookInfo,
  });

  final VoidCallback onTap;
  final HadithBookInfo bookInfo;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return BlocBuilder<DownloadBookCubit, DownloadBookState>(
      builder: (context, state) {
        final downloading = state.isCurrentlyDownloading(bookInfo.slug);
        final downloaded = state.downloadedBooks.contains(bookInfo.slug);
        final progress = int.tryParse(state.getBookProgress(bookInfo.slug)) ?? 0;

        return SurfaceCard(
          padding: const EdgeInsets.all(14),
          radius: 14,
          onTap: onTap,
          child: Column(
            children: [
              Row(
                children: [
                  _BookAction(
                    downloaded: downloaded,
                    downloading: downloading,
                    progressPct: progress,
                    onDownload: () => context
                        .read<DownloadBookCubit>()
                        .downloadBook(bookSlug: bookInfo.slug),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookInfo.title,
                          style: TS.bold16.amiri.copyWith(
                            fontSize: 17,
                            color: scheme.onSurface,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bookInfo.arabicTitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bookInfo.author} · ${bookInfo.hadithCount.toLocalized(context)} ${S.of(context).hadith_total_label}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (downloading) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 3,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation(scheme.secondary),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BookAction extends StatelessWidget {
  const _BookAction({
    required this.downloaded,
    required this.downloading,
    required this.progressPct,
    required this.onDownload,
  });

  final bool downloaded;
  final bool downloading;
  final int progressPct;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final Color bg, fg, border;
    Widget content;

    if (downloaded) {
      const green = Color(0xFF3D9E6E);
      bg = green.withValues(alpha: 0.12);
      border = green.withValues(alpha: 0.30);
      fg = green;
      content = const HugeIcon(
        icon: HugeIcons.strokeRoundedTick02,
        color: green,
        size: 18,
      );
    } else if (downloading) {
      bg = scheme.onSurface.withValues(alpha: 0.06);
      border = scheme.onSurface.withValues(alpha: 0.25);
      fg = scheme.secondary;
      content = Text(
        '${progressPct.toLocalized(context)}%',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      );
    } else {
      bg = scheme.onSurface.withValues(alpha: 0.06);
      border = scheme.onSurface.withValues(alpha: 0.10);
      fg = scheme.onSurfaceVariant;
      content = HugeIcon(
        icon: HugeIcons.strokeRoundedDownload01,
        color: fg,
        size: 18,
      );
    }

    return GestureDetector(
      onTap: downloaded || downloading ? null : onDownload,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
