import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/utils/hadith_list_filter.dart';

Hadith _h(String number, HadithStatus status, int chapterId) => Hadith(
      hadithNumber: number,
      englishHadith: '',
      arabicHadith: '',
      englishNarrator: '',
      englishHeader: '',
      arabicHeader: '',
      status: status,
      chapterId: chapterId,
    );

void main() {
  final list = [
    _h('1', HadithStatus.sahih, 1),
    _h('2', HadithStatus.hasan, 1),
    _h('3', HadithStatus.daeef, 2),
    _h('4', HadithStatus.sahih, 2),
  ];

  test('empty filter returns the list unchanged', () {
    const filter = HadithListFilter();
    expect(filter.isActive, isFalse);
    expect(applyHadithFilters(list, filter), same(list));
  });

  test('status filter keeps only the matching grade', () {
    const filter = HadithListFilter(status: HadithStatus.sahih);
    final result = applyHadithFilters(list, filter);
    expect(result.map((h) => h.hadithNumber), ['1', '4']);
  });

  test('chapter filter keeps only that chapter', () {
    const filter = HadithListFilter(chapterId: 2);
    final result = applyHadithFilters(list, filter);
    expect(result.map((h) => h.hadithNumber), ['3', '4']);
  });

  test('status and chapter combine (AND)', () {
    const filter =
        HadithListFilter(status: HadithStatus.sahih, chapterId: 2);
    final result = applyHadithFilters(list, filter);
    expect(result.map((h) => h.hadithNumber), ['4']);
  });

  test('toggleStatus selects, then re-tapping clears (single-select)', () {
    const base = HadithListFilter();
    final selected = base.toggleStatus(HadithStatus.sahih);
    expect(selected.status, HadithStatus.sahih);
    final cleared = selected.toggleStatus(HadithStatus.sahih);
    expect(cleared.status, isNull);
  });

  test('toggleStatus to a different grade replaces it', () {
    const base = HadithListFilter(status: HadithStatus.sahih);
    final replaced = base.toggleStatus(HadithStatus.daeef);
    expect(replaced.status, HadithStatus.daeef);
  });
}
