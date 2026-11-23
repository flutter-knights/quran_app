import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../core/constants/mushaf_paper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/screen_wake.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/entities/reciter.dart';
import '../../../surah/presentation/utils/mushaf_paper_colors.dart';
import '../../../tafsir/domain/usecases/get_ayah_tafsir.dart';
import '../../domain/entities/reel_request.dart';
import '../../domain/entities/reel_segment.dart';
import '../../domain/entities/share_card_content.dart';
import '../../domain/usecases/compose_ayah_reel.dart';
import '../../domain/usecases/get_share_card_content.dart';
import '../../domain/usecases/prepare_ayah_audio.dart';
import '../utils/ayah_share_text.dart';
import '../utils/reel_frame_painter.dart';
import '../utils/share_card_renderer.dart';

part 'ayah_share_state.dart';

class AyahShareCubit extends Cubit<AyahShareState> {
  AyahShareCubit({
    required this.ayah,
    required MushafPaper paper,
    required GetShareCardContent getContent,
    required ShareCardRenderer renderer,
    required GetAyahTafsir getTafsir,
    required PrepareAyahAudio prepareAudio,
    required ReelFramePainter framePainter,
    required ComposeAyahReel composeReel,
    ScreenWake screenWake = const ScreenWake(),
  }) : _getContent = getContent,
       _renderer = renderer,
       _getTafsir = getTafsir,
       _prepareAudio = prepareAudio,
       _framePainter = framePainter,
       _composeReel = composeReel,
       _wake = screenWake,
       super(AyahShareState(paper: paper));

  final AyahIdentifier ayah;
  final GetShareCardContent _getContent;
  final ShareCardRenderer _renderer;
  final GetAyahTafsir _getTafsir;
  final PrepareAyahAudio _prepareAudio;
  final ReelFramePainter _framePainter;
  final ComposeAyahReel _composeReel;
  final ScreenWake _wake;
  final _segmentCrops = <AyahIdentifier, ShareCardCrops>{};
  ShareCardContent? _content;
  ShareCardCrops? _crops;
  CancelToken? _token;
  final _segmentToken = CancelToken();
  var _encodeGeneration = 0;
  var _renderGeneration = 0;
  var _composeDeferred = false;

  Future<void> load() async {
    _renderGeneration++;
    _crops?.dispose();
    _crops = null;
    emit(state.copyWith(status: ShareCardStatus.loading));
    final result = await _getContent(ayah);
    if (isClosed) return;
    final content = result.toOption().toNullable();
    if (content == null) {
      emit(state.copyWith(status: ShareCardStatus.failed));
      return;
    }
    _content = content;
    final ShareCardCrops crops;
    try {
      crops = await _renderer.prepare(content);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: ShareCardStatus.failed));
      return;
    }
    if (isClosed) {
      crops.dispose();
      return;
    }
    _crops?.dispose();
    _crops = crops;
    await _compose();
  }

  void setPaper(MushafPaper paper) {
    if (paper == state.paper || state.reelWorking) return;
    emit(state.copyWith(paper: paper, reelIssue: ReelIssue.none));
    _compose();
  }

  void setIncludeTafsir(bool on) {
    if (state.status != ShareCardStatus.ready ||
        on == state.includeTafsir ||
        state.reelWorking) {
      return;
    }
    if (on) {
      emit(state.copyWith(includeTafsir: true, reelIssue: ReelIssue.none));
      if (state.tafsirStatus == ShareTafsirStatus.ready &&
          _missingTafsir().isEmpty) {
        _compose();
      } else {
        _loadTafsir();
      }
      return;
    }
    _token?.cancel();
    _token = null;
    emit(
      state.copyWith(
        includeTafsir: false,
        reelIssue: ReelIssue.none,
        tafsirStatus: state.tafsirStatus == ShareTafsirStatus.loading
            ? ShareTafsirStatus.idle
            : null,
      ),
    );
    if (state.tafsirStatus == ShareTafsirStatus.ready) _compose();
  }

  void retryTafsir() => setIncludeTafsir(true);

  Future<void> selectReel(Reciter reciter) async {
    if (state.status != ShareCardStatus.ready ||
        state.busy ||
        state.format != ShareFormat.image) {
      return;
    }
    if (reciter != state.reciter) {
      _disposeSegmentCrops();
      emit(state.copyWith(reelSegments: const [], reelCapped: false));
    }
    emit(
      state.copyWith(
        format: ShareFormat.reel,
        reciter: reciter,
        reelIssue: ReelIssue.none,
      ),
    );
    if (state.reelSegments.isEmpty) {
      emit(state.copyWith(export: ShareExport.preparing));
      final audio = (await _prepareAudio(
        ayah,
        reciter,
      )).toOption().toNullable();
      if (isClosed) return;
      if (audio == null) {
        _settle(
          state.copyWith(
            format: ShareFormat.image,
            export: ShareExport.idle,
            reelIssue: ReelIssue.audioFailed,
          ),
        );
        return;
      }
      _composeDeferred = false;
      emit(
        state.copyWith(
          reelSegments: [ReelSegment(content: _content!, audio: audio)],
          export: ShareExport.idle,
        ),
      );
    }
    await _compose();
  }

  void selectImage() {
    if (state.reelWorking || state.format == ShareFormat.image) return;
    emit(state.copyWith(format: ShareFormat.image, reelIssue: ReelIssue.none));
    _compose();
  }

  Future<void> addAyah() async {
    if (!state.canAddAyah) return;
    final last = state.reelSegments.last.ayah;
    final next = AyahIdentifier(surah: last.surah, ayah: last.ayah + 1);
    emit(
      state.copyWith(export: ShareExport.preparing, reelIssue: ReelIssue.none),
    );
    final audio = (await _prepareAudio(
      next,
      state.reciter!,
    )).toOption().toNullable();
    if (isClosed) return;
    if (audio == null) {
      _settle(
        state.copyWith(
          export: ShareExport.idle,
          reelIssue: ReelIssue.audioFailed,
        ),
      );
      return;
    }
    final rendered = await _renderSegment(next);
    if (isClosed) {
      rendered?.$2.dispose();
      return;
    }
    if (rendered == null) {
      _settle(
        state.copyWith(
          export: ShareExport.idle,
          reelIssue: ReelIssue.renderFailed,
        ),
      );
      return;
    }
    final (content, crops) = rendered;
    var segment = ReelSegment(content: content, audio: audio);
    if (state.reelDuration + segment.duration > reelMaxDuration) {
      crops.dispose();
      _settle(state.copyWith(reelCapped: true, export: ShareExport.idle));
      return;
    }
    if (state.includeTafsir) {
      final tafsir = await _segmentTafsir(segment);
      if (isClosed) {
        crops.dispose();
        return;
      }
      segment = segment.withTafsir(tafsir);
    }
    _segmentCrops[next] = crops;
    _composeDeferred = false;
    emit(
      state.copyWith(
        reelSegments: [...state.reelSegments, segment],
        export: ShareExport.idle,
      ),
    );
    await _compose();
  }

  Future<(ShareCardContent, ShareCardCrops)?> _renderSegment(
    AyahIdentifier ayah,
  ) async {
    final content = (await _getContent(ayah)).toOption().toNullable();
    if (content == null) return null;
    try {
      return (content, await _renderer.prepare(content));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _segmentTafsir(
    ReelSegment segment, [
    CancelToken? token,
  ]) async {
    final result = await _getTafsir(
      surah: segment.ayah.surah,
      ayah: segment.ayah.ayah,
      page: segment.content.page,
      cancelToken: token ?? _segmentToken,
    );
    return result.toOption().toNullable()?.body;
  }

  void removeAyah() {
    if (!state.canRemoveAyah) return;
    _segmentCrops.remove(state.reelSegments.last.ayah)?.dispose();
    emit(
      state.copyWith(
        reelSegments: state.reelSegments.sublist(0, state.reelCount - 1),
        reelCapped: false,
        reelIssue: ReelIssue.none,
      ),
    );
    _compose();
  }

  Future<void> requestShare() async {
    if (state.status != ShareCardStatus.ready ||
        state.cardBytes == null ||
        state.busy ||
        (state.format == ShareFormat.reel && state.reelSegments.isEmpty)) {
      return;
    }
    if (state.format == ShareFormat.image) {
      emit(state.copyWith(export: ShareExport.sharing));
      return;
    }
    await _encode();
  }

  void cancelEncode() {
    if (state.export != ShareExport.encoding) return;
    _encodeGeneration++;
    _composeReel.cancel();
  }

  Future<void> _encode() async {
    final generation = ++_encodeGeneration;
    emit(
      state.copyWith(
        export: ShareExport.encoding,
        encodeProgress: 0,
        reelIssue: ReelIssue.none,
        clearReelPath: true,
      ),
    );
    final withTafsir =
        state.includeTafsir && state.tafsirStatus == ShareTafsirStatus.ready;
    StreamSubscription<double>? progress;
    bool stale() {
      if (isClosed) return true;
      if (generation == _encodeGeneration) return false;
      _settle(
        state.copyWith(
          export: ShareExport.idle,
          encodeProgress: 0,
          reelIssue: ReelIssue.none,
        ),
      );
      return true;
    }

    try {
      progress = _composeReel.progress.listen((value) {
        if (isClosed) return;
        emit(state.copyWith(encodeProgress: value));
      });
      await _wake.hold(this, on: true);
      if (stale()) return;
      final clips = <ReelClip>[];
      for (var i = 0; i < state.reelCount; i++) {
        final segment = state.reelSegments[i];
        final frame = await _framePainter.paint(
          i == 0 ? _crops! : _segmentCrops[segment.ayah]!,
          colors: state.paper.colors,
          footer: reelFooter(state.reciter!, ayah, state.reelCount),
          tafsir: withTafsir ? (i == 0 ? state.tafsir : segment.tafsir) : null,
        );
        if (stale()) return;
        clips.add(ReelClip(frame: frame, audio: segment.audio));
      }
      final result = await _composeReel(ReelRequest(first: ayah, clips: clips));
      if (stale()) return;
      result.fold(
        (failure) => _settle(
          state.copyWith(
            export: ShareExport.idle,
            encodeProgress: 0,
            reelIssue: failure is ReelCancelledFailure
                ? ReelIssue.none
                : ReelIssue.encodeFailed,
          ),
        ),
        (path) =>
            emit(state.copyWith(export: ShareExport.sharing, reelPath: path)),
      );
    } catch (_) {
      if (isClosed) return;
      _settle(
        state.copyWith(
          export: ShareExport.idle,
          encodeProgress: 0,
          reelIssue: generation == _encodeGeneration
              ? ReelIssue.encodeFailed
              : ReelIssue.none,
        ),
      );
    } finally {
      await progress?.cancel();
      await _wake.hold(this, on: false);
    }
  }

  void shareFinished({required bool ok}) {
    if (isClosed || state.export != ShareExport.sharing) return;
    emit(state.copyWith(export: ok ? ShareExport.done : ShareExport.failed));
    if (_composeDeferred) {
      _composeDeferred = false;
      _compose();
    }
  }

  List<ReelSegment> _missingTafsir() => [
    for (final segment in state.reelSegments)
      if (segment.ayah != ayah && segment.tafsir == null) segment,
  ];

  Future<void> _loadTafsir() async {
    _token?.cancel();
    final token = _token = CancelToken();
    var body = state.tafsirStatus == ShareTafsirStatus.ready
        ? state.tafsir
        : null;
    emit(state.copyWith(tafsirStatus: ShareTafsirStatus.loading));
    if (body == null) {
      final result = await _getTafsir(
        surah: ayah.surah,
        ayah: ayah.ayah,
        page: _content!.page,
        cancelToken: token,
      );
      if (isClosed || token != _token) return;
      body = result.toOption().toNullable()?.body;
      if (body == null) {
        emit(
          state.copyWith(
            includeTafsir: false,
            tafsirStatus: ShareTafsirStatus.failed,
          ),
        );
        return;
      }
    }
    final missing = _missingTafsir();
    final bodies = await Future.wait([
      for (final segment in missing) _segmentTafsir(segment, token),
    ]);
    if (isClosed || token != _token) return;
    final fetched = {
      for (var i = 0; i < missing.length; i++) missing[i].ayah: bodies[i],
    };
    emit(
      state.copyWith(
        tafsir: body,
        tafsirStatus: ShareTafsirStatus.ready,
        reelSegments: [
          for (final segment in state.reelSegments)
            fetched[segment.ayah] == null
                ? segment
                : segment.withTafsir(fetched[segment.ayah]),
        ],
      ),
    );
    await _compose();
  }

  Future<void> _compose() async {
    final crops = _crops;
    if (crops == null) return;
    if (state.export == ShareExport.sharing || state.reelWorking) {
      _composeDeferred = true;
      return;
    }
    final generation = ++_renderGeneration;
    if (state.cardBytes != null) {
      emit(state.copyWith(export: ShareExport.rendering));
    }
    final withTafsir =
        state.includeTafsir && state.tafsirStatus == ShareTafsirStatus.ready;
    try {
      final tafsir = withTafsir ? state.tafsir : null;
      final bytes =
          state.format == ShareFormat.reel && state.reelSegments.isNotEmpty
          ? await _framePainter.paint(
              crops,
              colors: state.paper.colors,
              footer: reelFooter(state.reciter!, ayah, state.reelCount),
              tafsir: tafsir,
            )
          : await _renderer.compose(
              crops,
              colors: state.paper.colors,
              tafsir: tafsir,
            );
      if (isClosed || generation != _renderGeneration) return;
      emit(
        state.copyWith(
          status: ShareCardStatus.ready,
          cardBytes: bytes,
          renderId: state.renderId + 1,
          export: ShareExport.idle,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _renderGeneration) return;
      if (withTafsir) {
        emit(state.copyWith(includeTafsir: false, export: ShareExport.idle));
        await _compose();
        return;
      }
      emit(
        state.copyWith(
          status: ShareCardStatus.failed,
          export: ShareExport.idle,
        ),
      );
    }
  }

  void _settle(AyahShareState next) {
    emit(next);
    if (_composeDeferred) {
      _composeDeferred = false;
      _compose();
    }
  }

  void _disposeSegmentCrops() {
    for (final crops in _segmentCrops.values) {
      crops.dispose();
    }
    _segmentCrops.clear();
  }

  @override
  Future<void> close() {
    _token?.cancel();
    _segmentToken.cancel();
    _composeReel.cancel();
    _crops?.dispose();
    _disposeSegmentCrops();
    return super.close();
  }
}
