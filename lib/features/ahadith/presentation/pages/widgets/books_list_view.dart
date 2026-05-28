import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_bar_center_title.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_book_info.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart';
import 'package:quran_app/generated/l10n.dart';

class BooksListView extends StatelessWidget {
  const BooksListView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final books = getHadithBooks(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  AppBarCenterTitle(
                    label: S.of(context).collections_label,
                    title: S.of(context).hadith_books_appbar_title,
                  ),
                  const Spacer(),
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push(AppRouter.settingsPath),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSectionHeader(
                      label: S.of(context).books_section,
                      trailing: Text(
                        S.of(context).books_count(
                              books.length.toLocalized(context),
                            ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final book in books) ...[
                      HadithBookListItem(
                        bookInfo: book,
                        onTap: () => context.push(
                          AppRouter.ahadithPath,
                          extra: book.slug,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
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

List<HadithBookInfo> getHadithBooks(BuildContext context) {
  final s = S.of(context);
  return [
    HadithBookInfo(
      slug: 'sahih-bukhari',
      title: s.sahih_bukhari,
      arabicTitle: s.full_title_bukhari,
      author: s.author_bukhari,
      authorDeath: s.death_bukhari,
      hadithCount: 7563,
    ),
    HadithBookInfo(
      slug: 'sahih-muslim',
      title: s.sahih_muslim,
      arabicTitle: s.full_title_muslim,
      author: s.author_muslim,
      authorDeath: s.death_muslim,
      hadithCount: 7500,
    ),
    HadithBookInfo(
      slug: 'al-tirmidhi',
      title: s.al_tirmidhi,
      arabicTitle: s.full_title_tirmidhi,
      author: s.author_tirmidhi,
      authorDeath: s.death_tirmidhi,
      hadithCount: 4400,
    ),
    HadithBookInfo(
      slug: 'abu-dawood',
      title: s.abu_dawood,
      arabicTitle: s.full_title_abu_dawood,
      author: s.author_abu_dawood,
      authorDeath: s.death_abu_dawood,
      hadithCount: 5274,
    ),
    HadithBookInfo(
      slug: 'ibn-e-majah',
      title: s.ibn_e_majah,
      arabicTitle: s.full_title_ibn_majah,
      author: s.author_ibn_majah,
      authorDeath: s.death_ibn_majah,
      hadithCount: 4341,
    ),
    HadithBookInfo(
      slug: 'sunan-nasai',
      title: s.sunan_nasai,
      arabicTitle: s.full_title_nasai,
      author: s.author_nasai,
      authorDeath: s.death_nasai,
      hadithCount: 5758,
    ),
    HadithBookInfo(
      slug: 'mishkat',
      title: s.mishkat,
      arabicTitle: s.full_title_mishkat,
      author: s.author_mishkat,
      authorDeath: s.death_mishkat,
      hadithCount: 5945,
    ),
  ];
}
