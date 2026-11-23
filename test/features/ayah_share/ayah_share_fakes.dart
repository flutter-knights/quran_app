import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/presentation/cubit/ayah_share_cubit.dart';
import 'package:quran_app/features/ayah_share/domain/entities/reel_request.dart';
import 'package:quran_app/features/ayah_share/domain/entities/share_card_content.dart';
import 'package:quran_app/features/ayah_share/domain/usecases/compose_ayah_reel.dart';
import 'package:quran_app/features/ayah_share/domain/usecases/get_share_card_content.dart';
import 'package:quran_app/features/ayah_share/domain/usecases/prepare_ayah_audio.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/reel_frame_painter.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_layout.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_renderer.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
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
  final requests = <({int surah, int ayah, int page})>[];

  @override
  Future<Either<Failure, Tafsir>> call({
    required int surah,
    required int ayah,
    required int page,
    required CancelToken cancelToken,
  }) {
    requests.add((surah: surah, ayah: ayah, page: page));
    tokens.add(cancelToken);
    final completer = Completer<Either<Failure, Tafsir>>();
    completers.add(completer);
    return completer.future;
  }
}

class FakePrepareAyahAudio implements PrepareAyahAudio {
  final durations = <AyahIdentifier, Duration>{};
  final failing = <AyahIdentifier>{};
  final requests = <AyahIdentifier>[];
  Completer<void>? gate;

  @override
  Future<Either<Failure, List<ReelAudio>>> call(
    AyahIdentifier ayah,
    Reciter reciter,
  ) async {
    requests.add(ayah);
    await gate?.future;
    if (failing.contains(ayah)) return const Left(NetworkFailure('offline'));
    return Right([
      if (ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9)
        const ReelAudio(path: '/a/1_1.mp3', duration: Duration(seconds: 6)),
      ReelAudio(
        path: '/a/${ayah.surah}_${ayah.ayah}.mp3',
        duration: durations[ayah] ?? const Duration(seconds: 5),
      ),
    ]);
  }
}

typedef PaintCall = ({
  ShareCardCrops crops,
  MushafPaperColors colors,
  String footer,
  String? tafsir,
});

class FakeReelFramePainter implements ReelFramePainter {
  final calls = <PaintCall>[];
  var throwing = false;
  Completer<void>? gate;

  @override
  Future<Uint8List> paint(
    ShareCardCrops crops, {
    required MushafPaperColors colors,
    required String footer,
    String? tafsir,
  }) async {
    calls.add((crops: crops, colors: colors, footer: footer, tafsir: tafsir));
    await gate?.future;
    if (throwing) throw StateError('paint');
    return Uint8List.fromList(onePixelPng);
  }
}

class FakeComposeAyahReel implements ComposeAyahReel {
  final requests = <ReelRequest>[];
  Completer<Either<Failure, String>>? completer;
  final progressCtrl = StreamController<double>.broadcast();
  var cancels = 0;

  @override
  Future<Either<Failure, String>> call(ReelRequest request) {
    requests.add(request);
    return completer?.future ??
        Future.value(Right('/reels/${request.fileName}'));
  }

  @override
  Stream<double> get progress => progressCtrl.stream;

  @override
  Future<void> cancel() async {
    cancels++;
    final pending = completer;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const Left(ReelCancelledFailure()));
    }
  }
}

typedef FakeAyahShare = ({
  FakeGetShareCardContent content,
  FakeShareCardRenderer renderer,
  FakeGetAyahTafsir tafsir,
  FakePrepareAyahAudio prepareAudio,
  FakeReelFramePainter framePainter,
  FakeComposeAyahReel composeReel,
});

FakeAyahShare registerFakeAyahShare({
  FakeGetShareCardContent? content,
  FakeShareCardRenderer? renderer,
  FakeGetAyahTafsir? tafsir,
  FakePrepareAyahAudio? prepareAudio,
  FakeReelFramePainter? framePainter,
  FakeComposeAyahReel? composeReel,
}) {
  final fakes = (
    content: content ?? FakeGetShareCardContent(),
    renderer: renderer ?? FakeShareCardRenderer(),
    tafsir: tafsir ?? FakeGetAyahTafsir(),
    prepareAudio: prepareAudio ?? FakePrepareAyahAudio(),
    framePainter: framePainter ?? FakeReelFramePainter(),
    composeReel: composeReel ?? FakeComposeAyahReel(),
  );
  sl.registerFactoryParam<AyahShareCubit, AyahIdentifier, MushafPaper>(
    (ayah, paper) => AyahShareCubit(
      ayah: ayah,
      paper: paper,
      getContent: fakes.content,
      renderer: fakes.renderer,
      getTafsir: fakes.tafsir,
      prepareAudio: fakes.prepareAudio,
      framePainter: fakes.framePainter,
      composeReel: fakes.composeReel,
    ),
  );
  return fakes;
}
