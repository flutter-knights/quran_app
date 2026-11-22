import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_hadith_by_number.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_state.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/books_list_view.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/places_groups.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';
import 'package:quran_app/generated/l10n.dart';

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
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(title: PendingS.of(context).menu_places),
            Expanded(
              child: BlocBuilder<HadithBookmarkCubit, HadithBookmarkState>(
                builder: (context, hadithState) {
                  final hadiths = hadithState.bookmarks.toList()
                    ..sort(
                      (a, b) => a.bookSlug != b.bookSlug
                          ? a.bookSlug.compareTo(b.bookSlug)
                          : a.hadithNumber.compareTo(b.hadithNumber),
                    );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    children: [
                      PlacesGroups(
                        onOpen: (page, focus) => context.push(
                          AppRouter.mushafPath,
                          extra: focus == null ? page : MushafArgs.focus(focus),
                        ),
                      ),
                      if (hadiths.isNotEmpty) ...[
                        const SizedBox(height: 20),
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
              ),
            ),
          ],
        ),
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
        SnackBar(content: Text(failure.message, style: TS.regular14)),
      ),
      (hadith) {
        if (hadith == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).coming_soon, style: TS.regular14),
            ),
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
              style: TS.bold14.copyWith(color: scheme.onSurface),
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
              icon: forwardArrowIcon(context),
              color: scheme.onSurfaceVariant,
              size: 16,
            ),
        ],
      ),
    );
  }
}
