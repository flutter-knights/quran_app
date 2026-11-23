import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/presentation/cubit/ayah_share_cubit.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';

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
  late AyahShareCubit cubit;
  late List<AyahShareState> states;

  setUp(() {
    content = FakeGetShareCardContent()..result = Right(contentFor(1, 1));
    renderer = FakeShareCardRenderer();
    getTafsir = FakeGetAyahTafsir();
    cubit = AyahShareCubit(
      ayah: ayah,
      paper: MushafPaper.cream,
      getContent: content,
      renderer: renderer,
      getTafsir: getTafsir,
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
      expect(cubit.state.cardBytes, isNot([9]));
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
}
