import 'package:equatable/equatable.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../core/helper functions/arabic_normalizer.dart';
import '../../../../core/helper functions/numeral_helpers.dart';

sealed class MenuQuery extends Equatable {
  const MenuQuery();
}

final class MenuQueryNone extends MenuQuery {
  const MenuQueryNone();

  @override
  List<Object?> get props => [];
}

final class MenuQueryOutOfRange extends MenuQuery {
  const MenuQueryOutOfRange();

  @override
  List<Object?> get props => [];
}

final class MenuQueryTarget extends MenuQuery {
  const MenuQueryTarget({
    required this.page,
    required this.surah,
    required this.juz,
  });

  final int page;
  final int surah;
  final int juz;

  @override
  List<Object?> get props => [page, surah, juz];
}

MenuQuery resolveMenuQuery(String raw) {
  final q = raw.trim();
  if (q.isEmpty) return const MenuQueryNone();
  final page = int.tryParse(toAsciiDigits(q));
  if (page != null) {
    if (page < 1 || page > 604) return const MenuQueryOutOfRange();
    final first = quran
        .getPageData(page)
        .firstWhere((e) => e['start'] != 0 || e['end'] != 0);
    return _target(page, first['surah'] as int);
  }
  final arabic = normalizeArabic(q);
  final latin = q.toLowerCase();
  for (var s = 1; s <= 114; s++) {
    if (normalizeArabic(quran.getSurahNameArabic(s)).contains(arabic) ||
        quran.getSurahName(s).toLowerCase().contains(latin)) {
      return _target(quran.getPageNumber(s, 1), s);
    }
  }
  return const MenuQueryNone();
}

MenuQueryTarget _target(int page, int surah) {
  final last = quran.getPageData(page).lastWhere((e) => (e['end'] as int) > 0);
  return MenuQueryTarget(
    page: page,
    surah: surah,
    juz: quran.getJuzNumber(last['surah'] as int, last['end'] as int),
  );
}
