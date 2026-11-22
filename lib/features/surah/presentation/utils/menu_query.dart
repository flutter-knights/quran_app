import 'dart:math' as math;

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

final _numeric = RegExp(r'^[+-]?\d+$');

MenuQuery resolveMenuQuery(String raw) {
  final q = raw.trim();
  if (q.isEmpty) return const MenuQueryNone();
  final digits = toAsciiDigits(q);
  if (_numeric.hasMatch(digits)) {
    final page = int.tryParse(digits);
    if (page == null || page < 1 || page > 604) {
      return const MenuQueryOutOfRange();
    }
    final first = quran
        .getPageData(page)
        .firstWhere((e) => e['start'] != 0 || e['end'] != 0);
    return _target(page, first['surah'] as int);
  }
  final arabic = normalizeArabic(q);
  if (arabic.isEmpty) return const MenuQueryNone();
  final bare = _bare(q);
  final latin = _latin(q);
  int? best;
  var bestRank = 3;
  for (var s = 1; s <= 114 && bestRank > 0; s++) {
    final name = quran.getSurahNameArabic(s);
    final rank = [
      _rank(normalizeArabic(name), arabic),
      if (bare.isNotEmpty) _rank(_bare(name), bare),
      if (latin.isNotEmpty) _rank(_latin(quran.getSurahName(s)), latin),
    ].reduce(math.min);
    if (rank < bestRank) {
      best = s;
      bestRank = rank;
    }
  }
  return best == null
      ? const MenuQueryNone()
      : _target(quran.getPageNumber(best, 1), best);
}

int _rank(String name, String query) => name == query
    ? 0
    : name.startsWith(query)
    ? 1
    : name.contains(query)
    ? 2
    : 3;

String _bare(String s) => normalizeArabic(s.trim().replaceFirst('ال', ''));

String _latin(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

MenuQueryTarget _target(int page, int surah) {
  final last = quran.getPageData(page).lastWhere((e) => (e['end'] as int) > 0);
  return MenuQueryTarget(
    page: page,
    surah: surah,
    juz: quran.getJuzNumber(last['surah'] as int, last['end'] as int),
  );
}
