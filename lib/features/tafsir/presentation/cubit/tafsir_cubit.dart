import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/services/quran_page_service.dart';
import '../../domain/entities/tafsir.dart';
import '../../domain/usecases/get_ayah_tafsir.dart';

part 'tafsir_state.dart';

class TafsirCubit extends Cubit<TafsirState> {
  TafsirCubit({
    required GetAyahTafsir getAyahTafsir,
    required QuranPageService pageService,
  }) : _getAyahTafsir = getAyahTafsir,
       _pageService = pageService,
       super(const TafsirIdle());

  final GetAyahTafsir _getAyahTafsir;
  final QuranPageService _pageService;
  var _request = 0;

  Future<void> load(AyahIdentifier ayah) async {
    if (ayah.ayah == 0) {
      cancel();
      return;
    }
    final current = state;
    if (current is TafsirLoaded && current.ayah == ayah) return;
    final request = ++_request;
    emit(TafsirLoading(ayah));
    final result = await _getAyahTafsir(
      surah: ayah.surah,
      ayah: ayah.ayah,
      page: _pageService.getPageForAyah(ayah.surah, ayah.ayah),
    );
    if (isClosed || request != _request) return;
    emit(
      result.fold(
        (_) => TafsirFailed(ayah),
        (tafsir) => TafsirLoaded(ayah, tafsir),
      ),
    );
  }

  Future<void> retry() async {
    final current = state;
    if (current is TafsirFailed) await load(current.ayah);
  }

  void cancel() {
    _getAyahTafsir.cancel();
    _request++;
    if (!isClosed && state is TafsirLoading) emit(const TafsirIdle());
  }

  @override
  Future<void> close() {
    _getAyahTafsir.cancel();
    return super.close();
  }
}
