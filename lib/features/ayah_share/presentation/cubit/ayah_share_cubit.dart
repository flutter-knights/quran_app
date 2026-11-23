import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/mushaf_paper.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../surah/presentation/utils/mushaf_paper_colors.dart';
import '../../../tafsir/domain/usecases/get_ayah_tafsir.dart';
import '../../domain/entities/share_card_content.dart';
import '../../domain/usecases/get_share_card_content.dart';
import '../utils/share_card_renderer.dart';

part 'ayah_share_state.dart';

class AyahShareCubit extends Cubit<AyahShareState> {
  AyahShareCubit({
    required this.ayah,
    required MushafPaper paper,
    required GetShareCardContent getContent,
    required ShareCardRenderer renderer,
    required GetAyahTafsir getTafsir,
  }) : _getContent = getContent,
       _renderer = renderer,
       _getTafsir = getTafsir,
       super(AyahShareState(paper: paper));

  final AyahIdentifier ayah;
  final GetShareCardContent _getContent;
  final ShareCardRenderer _renderer;
  final GetAyahTafsir _getTafsir;
  ShareCardContent? _content;
  ShareCardCrops? _crops;
  CancelToken? _token;
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
    if (paper == state.paper) return;
    emit(state.copyWith(paper: paper));
    _compose();
  }

  void setIncludeTafsir(bool on) {
    if (state.status != ShareCardStatus.ready || on == state.includeTafsir) {
      return;
    }
    if (on) {
      emit(state.copyWith(includeTafsir: true));
      if (state.tafsirStatus == ShareTafsirStatus.ready) {
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
        tafsirStatus: state.tafsirStatus == ShareTafsirStatus.loading
            ? ShareTafsirStatus.idle
            : null,
      ),
    );
    if (state.tafsirStatus == ShareTafsirStatus.ready) _compose();
  }

  void retryTafsir() => setIncludeTafsir(true);

  void requestShare() {
    if (state.status != ShareCardStatus.ready ||
        state.cardBytes == null ||
        state.busy) {
      return;
    }
    emit(state.copyWith(export: ShareExport.sharing));
  }

  void shareFinished({required bool ok}) {
    if (isClosed || state.export != ShareExport.sharing) return;
    emit(state.copyWith(export: ok ? ShareExport.done : ShareExport.failed));
    if (_composeDeferred) {
      _composeDeferred = false;
      _compose();
    }
  }

  Future<void> _loadTafsir() async {
    _token?.cancel();
    final token = _token = CancelToken();
    emit(state.copyWith(tafsirStatus: ShareTafsirStatus.loading));
    final result = await _getTafsir(
      surah: ayah.surah,
      ayah: ayah.ayah,
      page: _content!.page,
      cancelToken: token,
    );
    if (isClosed || token != _token) return;
    final tafsir = result.toOption().toNullable();
    if (tafsir == null) {
      emit(
        state.copyWith(
          includeTafsir: false,
          tafsirStatus: ShareTafsirStatus.failed,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        tafsir: tafsir.body,
        tafsirStatus: ShareTafsirStatus.ready,
      ),
    );
    await _compose();
  }

  Future<void> _compose() async {
    final crops = _crops;
    if (crops == null) return;
    if (state.export == ShareExport.sharing) {
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
      final bytes = await _renderer.compose(
        crops,
        colors: state.paper.colors,
        tafsir: withTafsir ? state.tafsir : null,
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
      emit(
        state.copyWith(
          status: ShareCardStatus.failed,
          export: ShareExport.idle,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _token?.cancel();
    _crops?.dispose();
    return super.close();
  }
}
