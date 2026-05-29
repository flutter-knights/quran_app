import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_hadith_by_number.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_state.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/books_list_view.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/generated/l10n.dart';

/// Unified bookmarks: saved Quran ayahs and saved ahadith, in sections.
/// The ayah [BookmarkCubit] is provided app-wide (main.dart); the
/// [HadithBookmarkCubit] singleton is provided here.
class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<HadithBookmarkCubit>(),
      child: const _BookmarksView(),
    );
  }
}

class _BookmarksView extends StatelessWidget {
  const _BookmarksView();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(title: S.of(context).bookmarks_screen_title),
            Expanded(
              child: BlocBuilder<BookmarkCubit, BookmarkState>(
                builder: (context, ayahState) {
                  return BlocBuilder<HadithBookmarkCubit, HadithBookmarkState>(
                    builder: (context, hadithState) {
                      final ayahs = ayahState.bookmarks.toList()
                        ..sort((a, b) => a.surah != b.surah
                            ? a.surah.compareTo(b.surah)
                            : a.ayah.compareTo(b.ayah));
                      final hadiths = hadithState.bookmarks.toList()
                        ..sort((a, b) => a.bookSlug != b.bookSlug
                            ? a.bookSlug.compareTo(b.bookSlug)
                            : a.hadithNumber.compareTo(b.hadithNumber));

                      if (ayahs.isEmpty && hadiths.isEmpty) {
                        return Center(
                          child: Text(
                            S.of(context).no_bookmarks_yet,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                        children: [
                          if (ayahs.isNotEmpty) ...[
                            AppSectionHeader(
                              label: S.of(context).bookmarks_quran_section,
                            ),
                            const SizedBox(height: 10),
                            for (final a in ayahs) ...[
                              _QuranBookmarkTile(ayah: a),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (hadiths.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            AppSectionHeader(
                              label: S.of(context).bookmarks_ahadith_section,
                            ),
                            const SizedBox(height: 10),
                            for (final h in hadiths) ...[
                              _AhadithBookmarkTile(bookmark: h),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuranBookmarkTile extends StatelessWidget {
  const _QuranBookmarkTile({required this.ayah});
  final AyahIdentifier ayah;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final surahName = context.isArabic
        ? quran.getSurahNameArabic(ayah.surah)
        : quran.getSurahName(ayah.surah);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 12,
      onTap: () => context.push(
        AppRouter.mushafPath,
        extra: quran.getPageNumber(ayah.surah, ayah.ayah),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedBookOpen01,
            color: scheme.secondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surahName,
                  style: TS.bold16.copyWith(fontSize: 14, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ayah.surah.toLocalized(context)} : ${ayah.ayah.toLocalized(context)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: scheme.onSurfaceVariant,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _AhadithBookmarkTile extends StatefulWidget {
  const _AhadithBookmarkTile({required this.bookmark});
  final HadithBookmark bookmark;

  @override
  State<_AhadithBookmarkTile> createState() => _AhadithBookmarkTileState();
}

class _AhadithBookmarkTileState extends State<_AhadithBookmarkTile> {
  bool _loading = false;

  String _bookTitle(BuildContext context) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == widget.bookmark.bookSlug) return b.title;
    }
    return widget.bookmark.bookSlug;
  }

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await sl<GetHadithByNumber>().call(
      bookSlug: widget.bookmark.bookSlug,
      hadithNumber: widget.bookmark.hadithNumber,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (hadith) {
        if (hadith == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).coming_soon)),
          );
        } else {
          context.push(
            AppRouter.hadithPath,
            extra: (hadith: hadith, bookSlug: widget.bookmark.bookSlug),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 12,
      onTap: _open,
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedBookmark01,
            color: scheme.secondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_bookTitle(context)} · #${widget.bookmark.hadithNumber.toLocalized(context)}',
              style: TS.bold16.copyWith(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          if (_loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.secondary,
              ),
            )
          else
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: scheme.onSurfaceVariant,
              size: 16,
            ),
        ],
      ),
    );
  }
}
