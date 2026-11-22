import 'dart:math' as math;
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:quran/quran.dart' as quran;

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/entities/ayah_bound_entity.dart';
import '../../domain/entities/normalized_rect.dart';

const mushafPageSize = Size(1536, 2795);
final mushafPageAspect = mushafPageSize.aspectRatio;

({AyahIdentifier start, AyahIdentifier end})? listenRange({
  AyahIdentifier? selected,
  required List<AyahBoundEntity> ayahs,
}) {
  final AyahIdentifier start;
  if (selected != null) {
    start = AyahIdentifier(surah: selected.surah, ayah: selected.realAyah);
  } else {
    final real = ayahs.where((b) => b.ayah.ayah > 0);
    if (real.isEmpty) return null;
    start = real.first.ayah;
  }
  return (
    start: start,
    end: AyahIdentifier(
      surah: start.surah,
      ayah: quran.getVerseCount(start.surah),
    ),
  );
}

enum PlaybackScope { none, surahEnd, pageEnd }

PlaybackScope playbackScope(AyahIdentifier? start, AyahIdentifier? end) {
  if (start == null || end == null) return PlaybackScope.none;
  if (start.surah == end.surah && end.ayah == quran.getVerseCount(end.surah)) {
    return PlaybackScope.surahEnd;
  }
  final last = quran
      .getPageData(quran.getPageNumber(end.surah, end.ayah))
      .lastWhere((e) => (e['end'] as int) > 0);
  return last['surah'] == end.surah && last['end'] == end.ayah
      ? PlaybackScope.pageEnd
      : PlaybackScope.none;
}

double? lineBottomOf(List<AyahBoundEntity> ayahs, AyahIdentifier? ayah) {
  if (ayah == null) return null;
  for (final b in ayahs) {
    if (b.ayah == ayah && b.lines.isNotEmpty) {
      return b.lines.map((l) => l.y + l.h).reduce(math.max);
    }
  }
  return null;
}

NormalizedRect? firstLineOf(List<AyahBoundEntity> ayahs, AyahIdentifier ayah) {
  for (final b in ayahs) {
    if (b.ayah == ayah && b.lines.isNotEmpty) return b.lines.first;
  }
  return null;
}

double? firstLineBottomOf(List<AyahBoundEntity> ayahs, AyahIdentifier ayah) {
  final line = firstLineOf(ayahs, ayah);
  return line == null ? null : line.y + line.h;
}

double? pageTextLeftOf(List<AyahBoundEntity> ayahs) {
  final lefts = [
    for (final b in ayahs)
      for (final l in b.lines) l.x,
  ];
  return lefts.isEmpty ? null : lefts.reduce(math.min);
}

double? pageBottomOf(List<AyahBoundEntity> ayahs) {
  final bottoms = [
    for (final b in ayahs)
      for (final l in b.lines) l.y + l.h,
  ];
  return bottoms.isEmpty ? null : bottoms.reduce(math.max);
}

double leafSlide({
  required Size area,
  required double lineBottom,
  required double overlay,
}) {
  final pageHeight = math.min(area.height, area.width / mushafPageAspect);
  final bottom = (area.height - pageHeight) / 2 + lineBottom * pageHeight;
  return (bottom - (area.height - overlay)).clamp(0.0, overlay);
}

sealed class ReaderNotice extends Equatable {
  const ReaderNotice();
}

final class ReturnToPageNotice extends ReaderNotice {
  const ReturnToPageNotice(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}

final class DownloadHintNotice extends ReaderNotice {
  const DownloadHintNotice(this.surah);

  final int surah;

  @override
  List<Object?> get props => [surah];
}

final class TapHintNotice extends ReaderNotice {
  const TapHintNotice();

  @override
  List<Object?> get props => [];
}

ReaderNotice? readerNotice({
  int? jumpFrom,
  int? downloadHintSurah,
  required bool hintSeen,
  bool audioError = false,
}) {
  if (jumpFrom != null) return ReturnToPageNotice(jumpFrom);
  if (downloadHintSurah != null && !audioError) {
    return DownloadHintNotice(downloadHintSurah);
  }
  return hintSeen ? null : const TapHintNotice();
}
