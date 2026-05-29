import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

/// Active filter for a hadith list. A null [status] means "all grades"; a null
/// [chapterId] means "all chapters". Status is single-select so it maps cleanly
/// onto the API's single-value `status` query param for online filtering.
class HadithListFilter {
  const HadithListFilter({this.status, this.chapterId});

  final HadithStatus? status;
  final int? chapterId;

  bool get isActive => status != null || chapterId != null;

  /// Tapping the active status clears it; tapping another replaces it.
  HadithListFilter toggleStatus(HadithStatus value) => HadithListFilter(
        status: status == value ? null : value,
        chapterId: chapterId,
      );

  HadithListFilter withChapter(int? id) =>
      HadithListFilter(status: status, chapterId: id);

  HadithListFilter clearChapter() =>
      HadithListFilter(status: status, chapterId: null);
}

/// Pure filter for the in-memory list. Returns [list] unchanged when no filter
/// is active. (Online results arrive already server-filtered, so this is a
/// no-op there and the authority for the downloaded/cached path.)
List<Hadith> applyHadithFilters(List<Hadith> list, HadithListFilter filter) {
  if (!filter.isActive) return list;
  return list.where((h) {
    if (filter.status != null && h.status != filter.status) return false;
    if (filter.chapterId != null && h.chapterId != filter.chapterId) {
      return false;
    }
    return true;
  }).toList();
}
