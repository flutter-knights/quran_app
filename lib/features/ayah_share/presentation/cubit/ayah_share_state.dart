part of 'ayah_share_cubit.dart';

enum ShareCardStatus { loading, ready, failed }

enum ShareTafsirStatus { idle, loading, ready, failed }

enum ShareExport { idle, rendering, sharing, done, failed }

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
  });

  final MushafPaper paper;
  final ShareCardStatus status;
  final bool includeTafsir;
  final ShareTafsirStatus tafsirStatus;
  final String? tafsir;
  final Uint8List? cardBytes;
  final int renderId;
  final ShareExport export;

  bool get busy =>
      export == ShareExport.rendering || export == ShareExport.sharing;

  bool get progress =>
      export == ShareExport.rendering ||
      tafsirStatus == ShareTafsirStatus.loading;

  AyahShareState copyWith({
    MushafPaper? paper,
    ShareCardStatus? status,
    bool? includeTafsir,
    ShareTafsirStatus? tafsirStatus,
    String? tafsir,
    Uint8List? cardBytes,
    int? renderId,
    ShareExport? export,
  }) => AyahShareState(
    paper: paper ?? this.paper,
    status: status ?? this.status,
    includeTafsir: includeTafsir ?? this.includeTafsir,
    tafsirStatus: tafsirStatus ?? this.tafsirStatus,
    tafsir: tafsir ?? this.tafsir,
    cardBytes: cardBytes ?? this.cardBytes,
    renderId: renderId ?? this.renderId,
    export: export ?? this.export,
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
  ];
}
