import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_book_info.dart';

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
    return PrettierTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.colorScheme.surfaceContainer,
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Text(bookInfo.title, style: TS.bold24),
            Text(bookInfo.arabicTitle, style: TS.bold16),
            Text(bookInfo.author, style: TS.bold16),
            Text(
              bookInfo.hadithCount.toString().toLocalized(context),
              style: TS.bold16,
            ),
          ],
        ),
      ),
    );
  }
}
