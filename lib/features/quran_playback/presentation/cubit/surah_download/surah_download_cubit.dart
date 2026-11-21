import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/failure.dart';
import '../../../domain/entities/reciter.dart';
import '../../../domain/repositories/quran_playback_repo.dart';
import 'surah_download_state.dart';

class SurahDownloadCubit extends Cubit<SurahDownloadState> {
  SurahDownloadCubit({required this.repository})
    : super(const SurahDownloadState());

  final QuranPlaybackRepo repository;
  final _subscriptions =
      <String, StreamSubscription<Either<Failure, double>>>{};

  SurahDownloadStatus statusOf(Reciter reciter, int surah) {
    final status = state.statuses[reciter.downloadKey(surah)];
    if (status != null) return status;
    return repository.isSurahDownloaded(surah: surah, reciter: reciter)
        ? const SurahDownloaded()
        : const SurahNotDownloaded();
  }

  void download(Reciter reciter, int surah) {
    final key = reciter.downloadKey(surah);
    if (state.statuses[key] is SurahDownloading) return;
    _set(key, const SurahDownloading(0));
    _subscriptions[key] = repository
        .downloadSurah(surah: surah, reciter: reciter)
        .listen(
          (result) => result.fold((_) {
            _drop(key);
            _set(key, const SurahDownloadFailed());
          }, (progress) => _set(key, SurahDownloading(progress))),
          onDone: () {
            if (_subscriptions.remove(key) != null) {
              _set(key, const SurahDownloaded());
            }
          },
        );
  }

  Future<void> cancel(Reciter reciter, int surah) async {
    final key = reciter.downloadKey(surah);
    await _subscriptions.remove(key)?.cancel();
    _set(key, const SurahNotDownloaded());
  }

  Future<void> delete(Reciter reciter, int surah) async {
    final key = reciter.downloadKey(surah);
    await _subscriptions.remove(key)?.cancel();
    final result = await repository.deleteSurahDownload(
      surah: surah,
      reciter: reciter,
    );
    result.fold((_) {}, (_) => _set(key, const SurahNotDownloaded()));
  }

  void _drop(String key) {
    final subscription = _subscriptions.remove(key);
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _set(String key, SurahDownloadStatus status) {
    if (isClosed) return;
    emit(SurahDownloadState(statuses: {...state.statuses, key: status}));
  }

  @override
  Future<void> close() async {
    await Future.wait(_subscriptions.values.map((s) => s.cancel()));
    _subscriptions.clear();
    return super.close();
  }
}
