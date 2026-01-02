import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: hadithSlugs
              .map(
                (slug) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: HadithBookListItem(
                    title: getLocalizedName(slug),
                    onTap: () => onPressed(context, bookSlug: slug),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

const List<String> hadithSlugs = [
  'sahih-bukhari',
  'sahih-muslim',
  'al-tirmidhi',
  'abu-dawood',
  'ibn-e-majah',
  'sunan-nasai',
  'mishkat',
  'musnad-ahmad',
  'al-silsila-sahiha',
];

String getLocalizedName(String slug) {
  final Map<String, String> localizedMap = {
    'sahih-bukhari': S.current.sahih_bukhari,
    'sahih-muslim': S.current.sahih_muslim,
    'al-tirmidhi': S.current.al_tirmidhi,
    'abu-dawood': S.current.abu_dawood,
    'ibn-e-majah': S.current.ibn_e_majah,
    'sunan-nasai': S.current.sunan_nasai,
    'mishkat': S.current.mishkat,
    'musnad-ahmad': S.current.musnad_ahmad,
    'al-silsila-sahiha': S.current.al_silsila_sahiha,
  };
  return localizedMap[slug] ?? slug;
}
