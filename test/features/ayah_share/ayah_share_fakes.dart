import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/presentation/cubit/ayah_share_cubit.dart';
import 'package:quran_app/features/ayah_share/domain/entities/share_card_content.dart';
import 'package:quran_app/features/ayah_share/domain/usecases/get_share_card_content.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_layout.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_renderer.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';
import 'package:quran_app/features/tafsir/domain/usecases/get_ayah_tafsir.dart';

final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class FakeGetShareCardContent implements GetShareCardContent {
  Either<Failure, ShareCardContent>? result;
  Completer<Either<Failure, ShareCardContent>>? completer;
  final requests = <AyahIdentifier>[];

  @override
  Future<Either<Failure, ShareCardContent>> call(AyahIdentifier ayah) {
    requests.add(ayah);
    return completer?.future ??
        Future.value(
          result ??
              Right(
                ShareCardContent(
                  ayah: ayah,
                  page: 1,
                  pageBounds: const [],
                  startPage: 1,
                  startPageBounds: const [],
                ),
              ),
        );
  }
}

class CountingCrops extends ShareCardCrops {
  CountingCrops()
    : super(
        layout: const ShareCardLayout(
          slices: [],
          rows: [],
          scale: 1,
          headerScale: 1,
          textBottom: 0,
          mergedTail: false,
        ),
        pieces: const [],
        basmalaOpacity: 0.42,
      );

  var disposed = 0;

  @override
  void dispose() {
    disposed++;
    super.dispose();
  }
}

typedef ComposeCall = ({MushafPaperColors colors, String? tafsir});

class FakeShareCardRenderer implements ShareCardRenderer {
  var prepareCount = 0;
  var failPrepare = false;
  var failCompose = false;
  var failComposeWithTafsir = false;
  Completer<void>? prepareCompleter;
  final composeCompleters = <Completer<Uint8List>>[];
  final composeCalls = <ComposeCall>[];
  final crops = <CountingCrops>[];

  @override
  Future<ShareCardCrops> prepare(ShareCardContent content) {
    prepareCount++;
    if (failPrepare) return Future.error(StateError('prepare'));
    final made = CountingCrops();
    crops.add(made);
    return prepareCompleter?.future.then((_) => made) ?? Future.value(made);
  }

  @override
  Future<Uint8List> compose(
    ShareCardCrops crops, {
    required MushafPaperColors colors,
    String? tafsir,
  }) {
    composeCalls.add((colors: colors, tafsir: tafsir));
    if (composeCompleters.isNotEmpty) {
      return composeCompleters.removeAt(0).future;
    }
    if (failCompose || (failComposeWithTafsir && tafsir != null)) {
      return Future.error(StateError('compose'));
    }
    return Future.value(Uint8List.fromList(onePixelPng));
  }
}

class FakeGetAyahTafsir implements GetAyahTafsir {
  final completers = <Completer<Either<Failure, Tafsir>>>[];
  final tokens = <CancelToken>[];

  @override
  Future<Either<Failure, Tafsir>> call({
    required int surah,
    required int ayah,
    required int page,
    required CancelToken cancelToken,
  }) {
    tokens.add(cancelToken);
    final completer = Completer<Either<Failure, Tafsir>>();
    completers.add(completer);
    return completer.future;
  }
}

typedef FakeAyahShare = ({
  FakeGetShareCardContent content,
  FakeShareCardRenderer renderer,
  FakeGetAyahTafsir tafsir,
});

FakeAyahShare registerFakeAyahShare({
  FakeGetShareCardContent? content,
  FakeShareCardRenderer? renderer,
  FakeGetAyahTafsir? tafsir,
}) {
  final fakes = (
    content: content ?? FakeGetShareCardContent(),
    renderer: renderer ?? FakeShareCardRenderer(),
    tafsir: tafsir ?? FakeGetAyahTafsir(),
  );
  sl.registerFactoryParam<AyahShareCubit, AyahIdentifier, MushafPaper>(
    (ayah, paper) => AyahShareCubit(
      ayah: ayah,
      paper: paper,
      getContent: fakes.content,
      renderer: fakes.renderer,
      getTafsir: fakes.tafsir,
    ),
  );
  return fakes;
}
