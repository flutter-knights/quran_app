import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/widgets/custom_app_bar.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_book_info.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart';
import 'package:quran_app/generated/l10n.dart';

class BooksListView extends StatelessWidget {
  const BooksListView({super.key});

  void onPressed(BuildContext context, {required String bookSlug}) {
    GoRouter.of(context).push(AppRouter.ahadithPath, extra: bookSlug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text('مكتبه الاحاديث')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: getHadithBooks(context)
              .map(
                (bookInfo) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: HadithBookListItem(
                    bookInfo: bookInfo,
                    onTap: () => onPressed(context, bookSlug: bookInfo.slug),
                  ),
                ),
              )
              .toList(),
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
