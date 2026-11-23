import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/presentation/cubit/ayah_share_cubit.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/ayah_share_text.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';

import '../../../surah/presentation/pages/mushaf/mushaf_page_harness.dart';
import '../../ayah_share_fakes.dart';
import '../../share_card_fixture.dart';

void main() {
  const ayah = AyahIdentifier(surah: 1, ayah: 1);
  const intro = Tafsir(
    surah: 1,
    ayah: 1,
    text: 'سورة الفاتحة مكية. بداية التفسير',
  );
  const textA = Tafsir(surah: 1, ayah: 1, text: 'A');
  const textB = Tafsir(surah: 1, ayah: 1, text: 'B');

  late FakeGetShareCardContent content;
  late FakeShareCardRenderer renderer;
  late FakeGetAyahTafsir getTafsir;
  late FakePrepareAyahAudio audio;
  late FakeReelFramePainter painter;
  late FakeComposeAyahReel compose;
  late FakeScreenWake wake;
  late AyahShareCubit cubit;
  late List<AyahShareState> states;

  setUp(() {
    content = FakeGetShareCardContent()..result = Right(contentFor(1, 1));
    renderer = FakeShareCardRenderer();
    getTafsir = FakeGetAyahTafsir();
    audio = FakePrepareAyahAudio();
    painter = FakeReelFramePainter();
    compose = FakeComposeAyahReel();
    wake = FakeScreenWake();
    cubit = AyahShareCubit(
      ayah: ayah,
      paper: MushafPaper.cream,
      getContent: content,
      renderer: renderer,
      getTafsir: getTafsir,
      prepareAudio: audio,
      framePainter: painter,
      composeReel: compose,
      screenWake: wake,
    );
    states = [];
    cubit.stream.listen(states.add);
  });

  tearDown(() => cubit.close());

  Future<void> loaded() async {
    await cubit.load();
    await pumpEventQueue();
  }

  test('load prepares the crops and emits the first card', () async {
    await loaded();

    expect(cubit.state.status, ShareCardStatus.ready);
    expect(cubit.state.renderId, 1);
    expect(cubit.state.cardBytes, isNotNull);
    expect(renderer.prepareCount, 1);
    expect(renderer.composeCalls, hasLength(1));
    expect(renderer.composeCalls.single.tafsir, isNull);
    expect(renderer.composeCalls.single.colors, MushafPaper.cream.colors);
  });

  test('a content failure emits failed', () async {
    content.result = const Left(NotFoundFailure('1:1'));

    await loaded();

    expect(cubit.state.status, ShareCardStatus.failed);
    expect(renderer.prepareCount, 0);
  });

  test('a render failure emits failed and load recovers', () async {
    renderer.failCompose = true;
    await loaded();
    expect(cubit.state.status, ShareCardStatus.failed);

    renderer.failCompose = false;
    await loaded();

    expect(cubit.state.status, ShareCardStatus.ready);
  });

  test('a tafsir compose failure falls back to the plain card', () async {
    await loaded();
    renderer.failComposeWithTafsir = true;

    cubit.setIncludeTafsir(true);
    await pumpEventQueue();
    getTafsir.completers.single.complete(const Right(intro));
    await pumpEventQueue();

    expect(cubit.state.status, ShareCardStatus.ready);
    expect(cubit.state.includeTafsir, isFalse);
    expect(renderer.composeCalls.map((c) => c.tafsir == null), [
      true,
      false,
      true,
    ]);
  });

  test('a reload drops a compose still in flight from the old crops', () async {
    renderer.failCompose = true;
    await loaded();
    renderer.failCompose = false;
    final held = Completer<Uint8List>();
    renderer.composeCompleters.add(held);
    cubit.setPaper(MushafPaper.night);
    renderer.prepareCompleter = Completer();
    final reloading = cubit.load();
    await pumpEventQueue();

    held.complete(Uint8List.fromList([7]));
    await pumpEventQueue();

    expect(cubit.state.status, ShareCardStatus.loading);
    expect(cubit.state.cardBytes, isNull);
    renderer.prepareCompleter!.complete();
    await reloading;
    await pumpEventQueue();
    expect(cubit.state.status, ShareCardStatus.ready);
    expect(cubit.state.cardBytes, onePixelPng);
    expect(
      states.where((s) => s.status == ShareCardStatus.ready),
      hasLength(1),
    );
  });

  test('overlapping loads dispose the crops they replace', () async {
    renderer.prepareCompleter = Completer();
    final first = cubit.load();
    final second = cubit.load();
    await pumpEventQueue();

    renderer.prepareCompleter!.complete();
    await Future.wait([first, second]);
    await pumpEventQueue();

    expect(renderer.crops, hasLength(2));
    expect(renderer.crops.first.disposed, 1);
    expect(renderer.crops.last.disposed, 0);
    expect(cubit.state.status, ShareCardStatus.ready);
  });

  test('a paper change recomposes without preparing again', () async {
    await loaded();

    cubit.setPaper(MushafPaper.night);
    await pumpEventQueue();

    expect(renderer.prepareCount, 1);
    expect(renderer.composeCalls, hasLength(2));
    expect(renderer.composeCalls.last.colors, MushafPaper.night.colors);
    expect(cubit.state.renderId, 2);
  });

  test('a stale compose never replaces a newer one', () async {
    await loaded();
    final sepia = Completer<Uint8List>();
    final night = Completer<Uint8List>();
    renderer.composeCompleters.addAll([sepia, night]);

    cubit.setPaper(MushafPaper.sepia);
    cubit.setPaper(MushafPaper.night);
    night.complete(Uint8List.fromList([2]));
    await pumpEventQueue();
    sepia.complete(Uint8List.fromList([1]));
    await pumpEventQueue();

    expect(cubit.state.paper, MushafPaper.night);
    expect(cubit.state.cardBytes, [2]);
    expect(cubit.state.renderId, 2);

    final staleSepia = Completer<Uint8List>();
    final freshNight = Completer<Uint8List>();
    renderer.composeCompleters.addAll([staleSepia, freshNight]);
    cubit.setPaper(MushafPaper.sepia);
    cubit.setPaper(MushafPaper.night);
    freshNight.complete(Uint8List.fromList([3]));
    await pumpEventQueue();
    staleSepia.completeError(StateError('stale'));
    await pumpEventQueue();

    expect(cubit.state.status, ShareCardStatus.ready);
    expect(cubit.state.export, ShareExport.idle);
    expect(cubit.state.cardBytes, [3]);
  });

  test(
    'turning the tafsir on loads it once and recomposes with its body',
    () async {
      await loaded();

      cubit.setIncludeTafsir(true);
      await pumpEventQueue();
      getTafsir.completers.single.complete(const Right(intro));
      await pumpEventQueue();

      expect(renderer.composeCalls.last.tafsir, 'بداية التفسير');

      cubit.setIncludeTafsir(false);
      await pumpEventQueue();
      expect(renderer.composeCalls.last.tafsir, isNull);

      cubit.setIncludeTafsir(true);
      await pumpEventQueue();

      expect(renderer.composeCalls.last.tafsir, 'بداية التفسير');
      expect(getTafsir.completers, hasLength(1));
    },
  );

  test('while the tafsir loads the plain card stays shareable', () async {
    await loaded();

    cubit.setIncludeTafsir(true);
    await pumpEventQueue();

    expect(cubit.state.progress, isTrue);
    expect(cubit.state.busy, isFalse);

    cubit.requestShare();

    expect(cubit.state.export, ShareExport.sharing);
  });

  test(
    'turning the tafsir off mid-load cancels it and never emits failed',
    () async {
      await loaded();
      cubit.setIncludeTafsir(true);
      await pumpEventQueue();

      cubit.setIncludeTafsir(false);
      getTafsir.completers.single.complete(const Left(ServerFailure('x')));
      await pumpEventQueue();

      expect(getTafsir.tokens.single.isCancelled, isTrue);
      expect(cubit.state.tafsirStatus, ShareTafsirStatus.idle);
      expect(cubit.state.includeTafsir, isFalse);
      expect(
        states.map((s) => s.tafsirStatus),
        isNot(contains(ShareTafsirStatus.failed)),
      );
    },
  );

  test('a cancelled tafsir load never lands after a new one starts', () async {
    await loaded();
    cubit.setIncludeTafsir(true);
    await pumpEventQueue();
    cubit.setIncludeTafsir(false);
    cubit.setIncludeTafsir(true);
    await pumpEventQueue();

    getTafsir.completers[1].complete(const Right(textB));
    await pumpEventQueue();
    getTafsir.completers[0].complete(const Right(textA));
    await pumpEventQueue();

    expect(cubit.state.tafsir, 'B');
    expect(renderer.composeCalls.last.tafsir, 'B');
  });

  test('a tafsir failure turns the switch off and retry asks again', () async {
    await loaded();
    cubit.setIncludeTafsir(true);
    await pumpEventQueue();

    getTafsir.completers.single.complete(const Left(ServerFailure('x')));
    await pumpEventQueue();

    expect(cubit.state.includeTafsir, isFalse);
    expect(cubit.state.tafsirStatus, ShareTafsirStatus.failed);

    cubit.retryTafsir();
    await pumpEventQueue();

    expect(getTafsir.completers, hasLength(2));
    expect(cubit.state.tafsirStatus, ShareTafsirStatus.loading);
  });

  test('share is ignored while a recompose runs', () async {
    await loaded();
    renderer.composeCompleters.add(Completer());

    cubit.setPaper(MushafPaper.night);
    cubit.requestShare();

    expect(cubit.state.export, ShareExport.rendering);
  });

  test('a second share request while sharing is ignored', () async {
    await loaded();

    cubit.requestShare();
    cubit.requestShare();
    await pumpEventQueue();

    expect(states.where((s) => s.export == ShareExport.sharing), hasLength(1));
  });

  test('shareFinished reports done or failed', () async {
    await loaded();

    cubit.requestShare();
    cubit.shareFinished(ok: true);
    expect(cubit.state.export, ShareExport.done);

    cubit.requestShare();
    cubit.shareFinished(ok: false);
    expect(cubit.state.export, ShareExport.failed);
  });

  test('tafsir toggles before the card is ready are ignored', () async {
    renderer.prepareCompleter = Completer();
    final loading = cubit.load();
    await pumpEventQueue();

    cubit.setIncludeTafsir(true);
    cubit.retryTafsir();
    await pumpEventQueue();

    expect(getTafsir.completers, isEmpty);
    expect(cubit.state.includeTafsir, isFalse);

    renderer.prepareCompleter!.complete();
    await loading;
  });

  test('a tafsir that lands mid-share waits for the share to finish', () async {
    await loaded();
    cubit.setIncludeTafsir(true);
    await pumpEventQueue();
    cubit.requestShare();

    getTafsir.completers.single.complete(const Right(intro));
    await pumpEventQueue();

    expect(renderer.composeCalls, hasLength(1));
    expect(cubit.state.export, ShareExport.sharing);
    expect(cubit.state.busy, isTrue);

    cubit.requestShare();
    expect(cubit.state.export, ShareExport.sharing);

    cubit.shareFinished(ok: true);
    await pumpEventQueue();

    expect(states.map((s) => s.export), contains(ShareExport.done));
    expect(renderer.composeCalls, hasLength(2));
    expect(renderer.composeCalls.last.tafsir, 'بداية التفسير');
    expect(cubit.state.renderId, 2);
  });

  test('shareFinished outside a share is ignored', () async {
    await loaded();
    renderer.composeCompleters.add(Completer());
    cubit.setPaper(MushafPaper.night);

    cubit.shareFinished(ok: true);

    expect(cubit.state.export, ShareExport.rendering);
  });

  test(
    'turning the tafsir off while its compose is pending shows the plain card',
    () async {
      await loaded();
      cubit.setIncludeTafsir(true);
      await pumpEventQueue();
      final held = Completer<Uint8List>();
      renderer.composeCompleters.add(held);
      getTafsir.completers.single.complete(const Right(intro));
      await pumpEventQueue();

      cubit.setIncludeTafsir(false);
      await pumpEventQueue();
      held.complete(Uint8List.fromList([9]));
      await pumpEventQueue();

      expect(renderer.composeCalls.last.tafsir, isNull);
      expect(cubit.state.cardBytes, onePixelPng);
      expect(cubit.state.renderId, 2);
    },
  );

  test('close disposes the crops and cancels the tafsir', () async {
    await loaded();
    cubit.setIncludeTafsir(true);
    await pumpEventQueue();

    await cubit.close();

    expect(renderer.crops.single.disposed, 1);
    expect(getTafsir.tokens.single.isCancelled, isTrue);
  });

  test('crops that arrive after close are disposed', () async {
    renderer.prepareCompleter = Completer();
    final loading = cubit.load();
    await pumpEventQueue();

    await cubit.close();
    renderer.prepareCompleter!.complete();
    await loading;

    expect(renderer.crops.single.disposed, 1);
    expect(renderer.composeCalls, isEmpty);
  });

  group('reel', () {
    Future<AyahShareCubit> reelCubit(AyahIdentifier a) async {
      content.result = null;
      final c = AyahShareCubit(
        ayah: a,
        paper: MushafPaper.cream,
        getContent: content,
        renderer: renderer,
        getTafsir: getTafsir,
        prepareAudio: audio,
        framePainter: painter,
        composeReel: compose,
        screenWake: wake,
      );
      states = [];
      c.stream.listen(states.add);
      addTearDown(c.close);
      await c.load();
      await pumpEventQueue();
      return c;
    }

    test(
      'choosing the reel prepares the start ayah and previews its first frame',
      () async {
        final c = await reelCubit(ayah);

        await c.selectReel(Reciter.alafasy);

        expect(c.state.format, ShareFormat.reel);
        expect(c.state.reelCount, 1);
        expect(c.state.reciter, Reciter.alafasy);
        expect(painter.calls, hasLength(1));
        expect(
          painter.calls.single.footer,
          reelFooter(Reciter.alafasy, ayah, 1),
        );
        expect(c.state.renderId, 2);
        expect(c.state.export, ShareExport.idle);
      },
    );

    test('an audio failure returns to the image with an audio issue', () async {
      final c = await reelCubit(ayah);
      audio.failing.add(ayah);

      await c.selectReel(Reciter.alafasy);

      expect(c.state.format, ShareFormat.image);
      expect(c.state.reelIssue, ReelIssue.audioFailed);
      expect(c.state.export, ShareExport.idle);
      expect(c.state.cardBytes, isNotNull);
      expect(painter.calls, isEmpty);
    });

    test(
      'adding an ayah prepares the next one and widens the footer range',
      () async {
        final c = await reelCubit(ayah);
        await c.selectReel(Reciter.alafasy);

        await c.addAyah();

        expect(c.state.reelCount, 2);
        expect(audio.requests.last, const AyahIdentifier(surah: 1, ayah: 2));
        expect(painter.calls.last.footer, endsWith('–٢'));
        expect(c.state.export, ShareExport.idle);
      },
    );

    test('a failing «+» raises the audio issue each time', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      audio.failing.add(const AyahIdentifier(surah: 1, ayah: 2));
      await pumpEventQueue();
      states.clear();

      await c.addAyah();
      await c.addAyah();
      await pumpEventQueue();

      expect(states.map((s) => s.reelIssue), [
        ReelIssue.none,
        ReelIssue.audioFailed,
        ReelIssue.none,
        ReelIssue.audioFailed,
      ]);
      expect(c.state.reelCount, 1);
    });

    test('a content failure on «+» raises the audio issue', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      content.result = const Left(NotFoundFailure('1:2'));

      await c.addAyah();

      expect(c.state.reelIssue, ReelIssue.audioFailed);
      expect(c.state.reelCount, 1);
      expect(c.state.export, ShareExport.idle);
    });

    test('a crop failure on «+» raises the audio issue', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      renderer.failPrepare = true;

      await c.addAyah();

      expect(c.state.reelIssue, ReelIssue.audioFailed);
      expect(c.state.reelCount, 1);
      expect(c.state.export, ShareExport.idle);
    });

    test('closing mid-«+» disposes the crops it prepared', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      renderer.prepareCompleter = Completer();
      final adding = c.addAyah();
      await pumpEventQueue();

      await c.close();
      renderer.prepareCompleter!.complete();
      await adding;

      expect(renderer.crops, hasLength(2));
      expect(renderer.crops.last.disposed, 1);
    });

    test('«+» reports progress while it prepares', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      expect(c.state.progress, isFalse);
      audio.gate = Completer();

      final adding = c.addAyah();

      expect(c.state.export, ShareExport.preparing);
      expect(c.state.progress, isTrue);
      audio.gate!.complete();
      await adding;
      expect(c.state.progress, isFalse);
    });

    test('«+» prepares only once on a double tap', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      final before = audio.requests.length;
      audio.gate = Completer();

      final first = c.addAyah();
      final second = c.addAyah();
      audio.gate!.complete();
      await Future.wait([first, second]);

      expect(audio.requests.length, before + 1);
      expect(c.state.reelCount, 2);
    });

    test('«+» is disabled at the surah end', () async {
      final c = await reelCubit(const AyahIdentifier(surah: 112, ayah: 4));

      await c.selectReel(Reciter.alafasy);

      expect(c.state.reelCount, 1);
      expect(c.state.canAddAyah, isFalse);
    });

    test('«+» is disabled at ten ayat', () async {
      final c = await reelCubit(const AyahIdentifier(surah: 2, ayah: 1));
      for (var i = 1; i <= 10; i++) {
        audio.durations[AyahIdentifier(surah: 2, ayah: i)] = const Duration(
          seconds: 3,
        );
      }
      await c.selectReel(Reciter.alafasy);

      for (var i = 0; i < 9; i++) {
        await c.addAyah();
      }

      expect(c.state.reelCount, 10);
      expect(c.state.canAddAyah, isFalse);
    });

    test('a start ayah over 60 s is allowed alone and blocks «+»', () async {
      final c = await reelCubit(ayah);
      audio.durations[ayah] = const Duration(seconds: 75);

      await c.selectReel(Reciter.alafasy);

      expect(c.state.reelCount, 1);
      expect(c.state.reelOverLimit, isTrue);
      expect(c.state.canAddAyah, isFalse);
    });

    test('an ayah that would pass 60 s is not added', () async {
      final c = await reelCubit(ayah);
      audio.durations[ayah] = const Duration(seconds: 40);
      audio.durations[const AyahIdentifier(surah: 1, ayah: 2)] = const Duration(
        seconds: 25,
      );
      await c.selectReel(Reciter.alafasy);

      await c.addAyah();

      expect(c.state.reelCount, 1);
      expect(c.state.reelCapped, isTrue);
      expect(c.state.canAddAyah, isFalse);
      expect(renderer.crops.last.disposed, 1);
      expect(c.state.export, ShareExport.idle);
    });

    test('removing an ayah disposes its crops and reopens «+»', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      await c.addAyah();
      expect(c.state.canRemoveAyah, isTrue);

      c.removeAyah();
      await pumpEventQueue();

      expect(c.state.reelCount, 1);
      expect(c.state.canRemoveAyah, isFalse);
      expect(c.state.canAddAyah, isTrue);
      expect(renderer.crops.last.disposed, 1);
      expect(painter.calls.last.footer, reelFooter(Reciter.alafasy, ayah, 1));
    });

    test('back to the image recomposes the card from the same crops', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      final prepared = renderer.prepareCount;
      final composed = renderer.composeCalls.length;

      c.selectImage();
      await pumpEventQueue();

      expect(c.state.format, ShareFormat.image);
      expect(renderer.prepareCount, prepared);
      expect(renderer.composeCalls, hasLength(composed + 1));
      expect(c.state.reelCount, 1);
    });

    test('another reciter drops the old segments', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      await c.addAyah();
      c.selectImage();
      await pumpEventQueue();

      await c.selectReel(Reciter.husary);

      expect(c.state.reciter, Reciter.husary);
      expect(c.state.reelCount, 1);
      expect(renderer.crops.last.disposed, 1);
      expect(audio.requests.where((a) => a == ayah), hasLength(2));
    });

    test('close disposes every segment crop', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      await c.addAyah();

      await c.close();

      expect(renderer.crops, hasLength(2));
      expect(renderer.crops.map((crops) => crops.disposed), [1, 1]);
    });

    test('a tafsir landing mid-prepare keeps preparing', () async {
      final c = await reelCubit(ayah);
      c.setIncludeTafsir(true);
      await pumpEventQueue();
      audio.gate = Completer();
      final composed = renderer.composeCalls.length;
      final selecting = c.selectReel(Reciter.alafasy);
      await pumpEventQueue();

      getTafsir.completers.single.complete(const Right(intro));
      await pumpEventQueue();

      expect(c.state.export, ShareExport.preparing);
      expect(c.state.canAddAyah, isFalse);
      expect(renderer.composeCalls, hasLength(composed));
      expect(painter.calls, isEmpty);

      audio.gate!.complete();
      await selecting;

      expect(painter.calls, hasLength(1));
      expect(painter.calls.single.tafsir, intro.body);
      expect(c.state.export, ShareExport.idle);
    });

    test('a tafsir landing mid-«+» keeps preparing and «+» closed', () async {
      final c = await reelCubit(ayah);
      await c.selectReel(Reciter.alafasy);
      c.setIncludeTafsir(true);
      await pumpEventQueue();
      audio.gate = Completer();
      final adding = c.addAyah();
      await pumpEventQueue();
      final requested = audio.requests.length;
      final painted = painter.calls.length;

      getTafsir.completers.single.complete(const Right(intro));
      await pumpEventQueue();
      await c.addAyah();

      expect(c.state.export, ShareExport.preparing);
      expect(c.state.canAddAyah, isFalse);
      expect(audio.requests, hasLength(requested));
      expect(painter.calls, hasLength(painted));

      audio.gate!.complete();
      await adding;

      expect(c.state.reelCount, 2);
      expect(painter.calls.last.tafsir, intro.body);
      expect(c.state.export, ShareExport.idle);
    });

    test(
      'an audio failure after a deferred tafsir composes the image card',
      () async {
        final c = await reelCubit(ayah);
        c.setIncludeTafsir(true);
        await pumpEventQueue();
        audio.gate = Completer();
        audio.failing.add(ayah);
        final selecting = c.selectReel(Reciter.alafasy);
        await pumpEventQueue();
        getTafsir.completers.single.complete(const Right(intro));
        await pumpEventQueue();

        audio.gate!.complete();
        await selecting;
        await pumpEventQueue();

        expect(c.state.format, ShareFormat.image);
        expect(c.state.reelIssue, ReelIssue.audioFailed);
        expect(renderer.composeCalls.last.tafsir, intro.body);
        expect(painter.calls, isEmpty);
      },
    );

    test('a paper change during the prepare is ignored', () async {
      final c = await reelCubit(ayah);
      audio.gate = Completer();
      final selecting = c.selectReel(Reciter.alafasy);
      await pumpEventQueue();

      c.setPaper(MushafPaper.night);
      c.setIncludeTafsir(true);
      c.selectImage();

      expect(c.state.paper, MushafPaper.cream);
      expect(c.state.includeTafsir, isFalse);
      expect(c.state.format, ShareFormat.reel);

      audio.gate!.complete();
      await selecting;
    });
  });

  group('encode', () {
    const start = AyahIdentifier(surah: 2, ayah: 255);

    Future<AyahShareCubit> reelCubit(AyahIdentifier a) async {
      content.result = null;
      final c = AyahShareCubit(
        ayah: a,
        paper: MushafPaper.cream,
        getContent: content,
        renderer: renderer,
        getTafsir: getTafsir,
        prepareAudio: audio,
        framePainter: painter,
        composeReel: compose,
        screenWake: wake,
      );
      states = [];
      c.stream.listen(states.add);
      addTearDown(c.close);
      await c.load();
      await pumpEventQueue();
      await c.selectReel(Reciter.alafasy);
      return c;
    }

    Future<AyahShareCubit> twoAyat() async {
      final c = await reelCubit(start);
      await c.addAyah();
      return c;
    }

    test('share paints every segment and sends one request', () async {
      final c = await twoAyat();
      final painted = painter.calls.length;

      await c.requestShare();

      expect(painter.calls, hasLength(painted + 2));
      expect(compose.requests, hasLength(1));
      final request = compose.requests.single;
      expect(request.first, start);
      expect(request.clips, hasLength(2));
      expect(
        request.clips.map((clip) => clip.audio),
        c.state.reelSegments.map((segment) => segment.audio),
      );
      expect(
        painter.calls[painted + 1].crops,
        isNot(same(painter.calls[painted].crops)),
      );
    });

    test('the basmala leads the first clip of a reel from ayah 1', () async {
      final c = await reelCubit(const AyahIdentifier(surah: 2, ayah: 1));

      await c.requestShare();

      expect(
        compose.requests.single.clips.first.audio.first.path,
        '/a/1_1.mp3',
      );
    });

    test('a new encode clears the previous reel path', () async {
      final c = await twoAyat();
      await c.requestShare();
      expect(c.state.reelPath, isNotNull);
      c.shareFinished(ok: true);
      compose.completer = Completer();

      final sharing = c.requestShare();
      await pumpEventQueue();

      expect(c.state.reelPath, isNull);
      compose.completer!.complete(const Right('/reels/x.mp4'));
      await sharing;
    });

    test('encode progress is mirrored into the state', () async {
      final c = await twoAyat();
      compose.completer = Completer();
      final sharing = c.requestShare();
      await pumpEventQueue();

      compose.progressCtrl.add(0.4);
      await pumpEventQueue();

      expect(c.state.encodeProgress, 0.4);
      compose.completer!.complete(const Right('/reels/x.mp4'));
      await sharing;
    });

    test('a finished encode hands the path to the share listener', () async {
      final c = await twoAyat();

      await c.requestShare();

      expect(c.state.export, ShareExport.sharing);
      expect(c.state.reelPath, '/reels/ayah_2_255-256.mp4');

      c.shareFinished(ok: true);

      expect(c.state.export, ShareExport.done);
    });

    test('cancel waits for the render to stop, then frees share', () async {
      final c = await twoAyat();
      compose.completer = Completer();
      final sharing = c.requestShare();
      await pumpEventQueue();

      c.cancelEncode();

      expect(compose.cancels, 1);
      expect(c.state.export, ShareExport.encoding);
      expect(c.state.canAddAyah, isFalse);

      await sharing;
      await pumpEventQueue();

      expect(c.state.export, ShareExport.idle);
      expect(c.state.reelIssue, ReelIssue.none);
      expect(wake.calls, [true, false]);

      compose.completer = null;
      await c.requestShare();

      expect(compose.requests, hasLength(2));
    });

    test('an encode failure raises encodeFailed and share retries', () async {
      final c = await twoAyat();
      compose.completer = Completer()
        ..complete(const Left(UnknownFailure('x')));

      await c.requestShare();

      expect(c.state.export, ShareExport.idle);
      expect(c.state.reelIssue, ReelIssue.encodeFailed);

      compose.completer = null;
      await c.requestShare();

      expect(compose.requests, hasLength(2));
      expect(c.state.export, ShareExport.sharing);
    });

    test('the screen stays awake only while encoding', () async {
      final c = await twoAyat();

      await c.requestShare();

      expect(wake.calls, [true, false]);

      c.shareFinished(ok: true);
      compose.completer = Completer()
        ..complete(const Left(UnknownFailure('x')));
      await c.requestShare();

      expect(wake.calls, [true, false, true, false]);
    });

    test(
      'with the tafsir on each later ayah loads its own and a failure draws it without',
      () async {
        final c = await twoAyat();
        c.setIncludeTafsir(true);
        await pumpEventQueue();
        getTafsir.completers.single.complete(const Right(intro));
        await pumpEventQueue();
        final painted = painter.calls.length;

        final sharing = c.requestShare();
        await pumpEventQueue();

        expect(getTafsir.completers, hasLength(2));
        expect(getTafsir.requests.last, (
          surah: 2,
          ayah: 256,
          page: c.state.reelSegments[1].content.page,
        ));
        getTafsir.completers.last.complete(const Left(ServerFailure('x')));
        await sharing;

        final encoded = painter.calls.sublist(painted);
        expect(encoded.map((call) => call.tafsir), [intro.body, isNull]);
        expect(c.state.export, ShareExport.sharing);
      },
    );

    test('toggles are ignored while encoding', () async {
      final c = await twoAyat();
      compose.completer = Completer();
      final sharing = c.requestShare();
      await pumpEventQueue();
      final composed = renderer.composeCalls.length;

      c.setPaper(MushafPaper.night);
      c.setIncludeTafsir(true);
      c.selectImage();
      await c.addAyah();

      expect(c.state.paper, MushafPaper.cream);
      expect(c.state.includeTafsir, isFalse);
      expect(c.state.format, ShareFormat.reel);
      expect(c.state.reelCount, 2);
      expect(c.state.export, ShareExport.encoding);
      expect(renderer.composeCalls, hasLength(composed));

      compose.completer!.complete(const Right('/reels/x.mp4'));
      await sharing;
    });

    test('close cancels a running encode and releases the wake', () async {
      final c = await twoAyat();
      compose.completer = Completer();
      final sharing = c.requestShare();
      await pumpEventQueue();

      await c.close();
      await sharing;

      expect(compose.cancels, 1);
      expect(wake.calls, [true, false]);
      expect(states.where((s) => s.export == ShareExport.sharing), isEmpty);
    });

    test(
      'a painter that throws settles with encodeFailed and frees the wake',
      () async {
        final c = await twoAyat();
        painter.throwing = true;

        await c.requestShare();

        expect(c.state.export, ShareExport.idle);
        expect(c.state.reelIssue, ReelIssue.encodeFailed);
        expect(compose.requests, isEmpty);
        expect(wake.calls, [true, false]);
      },
    );

    test('a throw after cancel is not reported as a failure', () async {
      final c = await twoAyat();
      painter.gate = Completer();
      painter.throwing = true;
      final sharing = c.requestShare();
      await pumpEventQueue();

      c.cancelEncode();
      painter.gate!.complete();
      await sharing;

      expect(c.state.export, ShareExport.idle);
      expect(c.state.reelIssue, ReelIssue.none);
      expect(wake.calls, [true, false]);
    });

    test('a tafsir landing mid-encode does not leave encoding', () async {
      final c = await twoAyat();
      c.setIncludeTafsir(true);
      await pumpEventQueue();
      compose.completer = Completer();
      final painted = painter.calls.length;
      final composed = renderer.composeCalls.length;
      final sharing = c.requestShare();
      await pumpEventQueue();

      getTafsir.completers.single.complete(const Right(intro));
      await pumpEventQueue();

      expect(c.state.export, ShareExport.encoding);
      expect(renderer.composeCalls, hasLength(composed));
      expect(painter.calls, hasLength(painted + 2));
      expect(painter.calls.sublist(painted).map((call) => call.tafsir), [
        isNull,
        isNull,
      ]);

      compose.completer!.complete(const Right('/reels/x.mp4'));
      await sharing;

      expect(c.state.export, ShareExport.sharing);

      c.shareFinished(ok: true);
      await pumpEventQueue();

      expect(painter.calls, hasLength(painted + 3));
      expect(painter.calls.last.tafsir, intro.body);
    });
  });
}
