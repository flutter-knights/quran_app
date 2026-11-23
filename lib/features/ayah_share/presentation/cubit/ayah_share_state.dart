part of 'ayah_share_cubit.dart';

enum ShareCardStatus { loading, ready, failed }

enum ShareTafsirStatus { idle, loading, ready, failed }

enum ShareExport { idle, rendering, preparing, encoding, sharing, done, failed }

enum ShareFormat { image, reel }

enum ReelIssue { none, audioFailed, encodeFailed }

final class AyahShareState extends Equatable {
  const AyahShareState({
    required this.paper,
    this.status = ShareCardStatus.loading,
    this.includeTafsir = false,
    this.tafsirStatus = ShareTafsirStatus.idle,
    this.tafsir,
    this.cardBytes,
    this.renderId = 0,
    this.export = ShareExport.idle,
    this.format = ShareFormat.image,
    this.reciter,
    this.reelSegments = const [],
    this.reelCapped = false,
    this.reelIssue = ReelIssue.none,
  });

  final MushafPaper paper;
  final ShareCardStatus status;
  final bool includeTafsir;
  final ShareTafsirStatus tafsirStatus;
  final String? tafsir;
  final Uint8List? cardBytes;
  final int renderId;
  final ShareExport export;
  final ShareFormat format;
  final Reciter? reciter;
  final List<ReelSegment> reelSegments;
  final bool reelCapped;
  final ReelIssue reelIssue;

  bool get reelWorking =>
      export == ShareExport.preparing || export == ShareExport.encoding;

  bool get busy =>
      export == ShareExport.rendering ||
      export == ShareExport.sharing ||
      reelWorking;

  bool get progress =>
      export == ShareExport.rendering ||
      export == ShareExport.preparing ||
      tafsirStatus == ShareTafsirStatus.loading;

  int get reelCount => reelSegments.length;

  Duration get reelDuration => reelSegments.fold(
    Duration.zero,
    (sum, segment) => sum + segment.duration,
  );

  bool get reelOverLimit => reelDuration > reelMaxDuration;

  bool get canAddAyah =>
      format == ShareFormat.reel &&
      !busy &&
      reelSegments.isNotEmpty &&
      !reelCapped &&
      reelCount < reelMaxAyat &&
      reelDuration < reelMaxDuration &&
      reelSegments.last.ayah.ayah <
          quran.getVerseCount(reelSegments.last.ayah.surah);

  bool get canRemoveAyah =>
      format == ShareFormat.reel && !busy && reelCount > 1;

  AyahShareState copyWith({
    MushafPaper? paper,
    ShareCardStatus? status,
    bool? includeTafsir,
    ShareTafsirStatus? tafsirStatus,
    String? tafsir,
    Uint8List? cardBytes,
    int? renderId,
    ShareExport? export,
    ShareFormat? format,
    Reciter? reciter,
    List<ReelSegment>? reelSegments,
    bool? reelCapped,
    ReelIssue? reelIssue,
  }) => AyahShareState(
    paper: paper ?? this.paper,
    status: status ?? this.status,
    includeTafsir: includeTafsir ?? this.includeTafsir,
    tafsirStatus: tafsirStatus ?? this.tafsirStatus,
    tafsir: tafsir ?? this.tafsir,
    cardBytes: cardBytes ?? this.cardBytes,
    renderId: renderId ?? this.renderId,
    export: export ?? this.export,
    format: format ?? this.format,
    reciter: reciter ?? this.reciter,
    reelSegments: reelSegments ?? this.reelSegments,
    reelCapped: reelCapped ?? this.reelCapped,
    reelIssue: reelIssue ?? this.reelIssue,
  );

  @override
  List<Object?> get props => [
    paper,
    status,
    includeTafsir,
    tafsirStatus,
    tafsir,
    renderId,
    export,
    format,
    reciter,
    reelSegments,
    reelCapped,
    reelIssue,
  ];
}
