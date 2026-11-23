import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/widgets/design/action_buttons_row.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/features/ayah_share/presentation/cubit/ayah_share_cubit.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/ayah_share_sheet.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/paper_swatches.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/share_card_preview.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../surah/presentation/pages/mushaf/mushaf_page_harness.dart';
import '../../ayah_share_fakes.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _shareFailed = 'تعذّر فتح نافذة المشاركة';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FakeAyahShare fakes;
  late FakeSettings settings;
  late List<Map<Object?, Object?>> shared;
  var shareThrows = false;

  setUp(() {
    shareThrows = false;
    shared = [];
    fakes = registerFakeAyahShare();
    settings = FakeSettings();
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      if (shareThrows) throw PlatformException(code: 'unavailable');
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'dev.fluttercommunity.plus/share/success';
    });
    final temp = Directory.systemTemp.createTempSync();
    addTearDown(() => temp.deleteSync(recursive: true));
    messenger.setMockMethodCallHandler(
      _pathChannel,
      (call) async => call.method == 'getTemporaryDirectory' ? temp.path : null,
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_pathChannel, null);
    await sl.reset();
  });

  Future<void> open(
    WidgetTester tester, {
    AyahIdentifier ayah = const AyahIdentifier(surah: 6, ayah: 31),
    Locale locale = const Locale('ar'),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<PlaybackCubit>.value(
            value: FakePlayback(const PlaybackState(reciter: Reciter.husary)),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => AyahShareSheet.show(context, ayah: ayah),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 250 && !done(); i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(done(), isTrue, reason: 'pumpUntil timed out');
  }

  final skeletons = find.byWidgetPredicate((w) => w is Skeletonizer);

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  Finder shareButton() => find.widgetWithText(ActionBtn, 'مشاركة');

  Finder textButton() => find.byKey(const ValueKey('share-text'));

  VoidCallback? onPressed(WidgetTester tester, Finder finder) =>
      tester.widget<ActionBtn>(finder).onPressed;

  testWidgets('opens with a skeleton, then the card preview', (tester) async {
    fakes.renderer.prepareCompleter = Completer<void>();
    await open(tester);
    expect(skeletons, findsOneWidget);
    expect(find.byKey(const ValueKey('share-preview-image')), findsNothing);

    fakes.renderer.prepareCompleter!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('share-preview-image')),
    );
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, 328);
    expect(resized.imageProvider, isA<MemoryImage>());
    expect((resized.imageProvider as MemoryImage).bytes, onePixelPng);
    expect(skeletons, findsNothing);
  });

  testWidgets('the tafsir switch loads it and keeps the plain card shareable', (
    tester,
  ) async {
    await open(tester);
    await tapVisible(tester, find.byKey(const ValueKey('share-tafsir')));
    await tester.pump();

    expect(fakes.tafsir.completers, hasLength(1));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(onPressed(tester, shareButton()), isNotNull);

    fakes.tafsir.completers.single.complete(
      const Right(Tafsir(surah: 6, ayah: 31, text: 'نص التفسير')),
    );
    await tester.pump();
    await tester.pump();

    expect(fakes.renderer.composeCalls.last.tafsir, 'نص التفسير');
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the tafsir switch is announced by the tile title', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    final tafsir = find.byKey(const ValueKey('share-tafsir'));

    expect(
      tester.getSemantics(tafsir),
      isSemantics(
        label: 'إضافة التفسير الميسر',
        hasToggledState: true,
        isToggled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('a tafsir failure shows the message with a retry', (
    tester,
  ) async {
    await open(tester);
    await tapVisible(tester, find.byKey(const ValueKey('share-tafsir')));
    await tester.pump();
    fakes.tafsir.completers.single.complete(
      const Left(NotFoundFailure('6:31')),
    );
    await tester.pump();

    expect(find.text('تعذّر تحميل التفسير'), findsOneWidget);
    expect(
      tester.widget<Switch>(find.byKey(const ValueKey('share-tafsir'))).value,
      isFalse,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('share-tafsir-retry')),
    );
    await tester.tap(find.byKey(const ValueKey('share-tafsir-retry')));
    await tester.pump();

    expect(fakes.tafsir.completers, hasLength(2));
  });

  testWidgets('a paper swatch recomposes on that paper', (tester) async {
    await open(tester);
    await tapVisible(tester, find.byKey(const ValueKey('share-paper-night')));
    await tester.pump();
    await tester.pump();

    expect(
      fakes.renderer.composeCalls.last.colors.background,
      MushafPaper.night.colors.background,
    );
  });

  testWidgets('opens on the reader paper from settings', (tester) async {
    settings.emit(
      SettingsState(
        settings.state.settingsModel.copyWith(mushafPaper: MushafPaper.night),
      ),
    );
    await open(tester);

    expect(
      fakes.renderer.composeCalls.first.colors.background,
      MushafPaper.night.colors.background,
    );
  });

  testWidgets('the list clears the bottom system inset', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await open(tester);

    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      const EdgeInsets.fromLTRB(16, 16, 16, 50),
    );
  });

  testWidgets('share hands the PNG with its name and the ayah label', (
    tester,
  ) async {
    await open(tester);
    await tapVisible(tester, shareButton());
    await pumpUntil(tester, () => shared.isNotEmpty);

    final args = shared.single;
    expect((args['paths'] as List).single, endsWith('ayah_6_31.png'));
    expect(args['mimeTypes'], ['image/png']);
    expect(args['text'], 'سورة الأنعام، الآية ٣١');
    expect(args['originWidth'] as double, greaterThan(0));
  });

  testWidgets('in English the share text is the English label', (tester) async {
    await open(tester, locale: const Locale('en'));
    await tapVisible(tester, find.widgetWithText(ActionBtn, 'Share'));
    await pumpUntil(tester, () => shared.isNotEmpty);

    expect(shared.single['text'], 'Surah ${quran.getSurahName(6)}, Ayah 31');
  });

  testWidgets('a failing share shows the message above the sheet', (
    tester,
  ) async {
    await open(tester);
    shareThrows = true;
    await tapVisible(tester, shareButton());
    await pumpUntil(
      tester,
      () => find.text(_shareFailed).evaluate().isNotEmpty,
    );

    expect(find.text(_shareFailed), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(SnackBar),
        matching: find.byType(BottomSheet),
      ),
      findsOneWidget,
    );
  });

  testWidgets('text only shares the verse without the basmala', (tester) async {
    await open(tester, ayah: const AyahIdentifier(surah: 2, ayah: 1));
    await tapVisible(tester, textButton());
    await pumpUntil(tester, () => shared.isNotEmpty);

    final text = shared.single['text'] as String;
    expect(text, startsWith('الم — '));
    expect(text, isNot(contains(quran.getVerse(2, 1).split(' ').first)));
  });

  testWidgets('a failing text share shows the message above the sheet', (
    tester,
  ) async {
    await open(tester);
    shareThrows = true;
    await tapVisible(tester, textButton());
    await pumpUntil(
      tester,
      () => find.text(_shareFailed).evaluate().isNotEmpty,
    );

    expect(find.text(_shareFailed), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(SnackBar),
        matching: find.byType(BottomSheet),
      ),
      findsOneWidget,
    );
  });

  testWidgets('buttons are disabled during a recompose', (tester) async {
    await open(tester);
    final held = Completer<Uint8List>();
    fakes.renderer.composeCompleters.add(held);
    await tapVisible(tester, find.byKey(const ValueKey('share-paper-night')));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(onPressed(tester, textButton()), isNull);
    expect(onPressed(tester, shareButton()), isNull);

    held.complete(Uint8List.fromList(onePixelPng));
    await tester.pump();
    await tester.pump();

    expect(onPressed(tester, textButton()), isNotNull);
    expect(onPressed(tester, shareButton()), isNotNull);
  });

  testWidgets('إغلاق closes the sheet', (tester) async {
    await open(tester);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();

    expect(find.byType(AyahShareSheet), findsNothing);
  });

  testWidgets('a render failure shows retry', (tester) async {
    fakes.renderer.failCompose = true;
    await open(tester);
    expect(find.text('تعذّر تجهيز الصورة'), findsOneWidget);

    fakes.renderer.failCompose = false;
    await tester.tap(find.byKey(const ValueKey('share-retry')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('share-preview-image')), findsOneWidget);
  });

  testWidgets('a retry after a render failure shows the skeleton again', (
    tester,
  ) async {
    await open(tester);
    fakes.renderer.failCompose = true;
    await tapVisible(tester, find.byKey(const ValueKey('share-paper-night')));
    await tester.pump();
    await tester.pump();
    expect(find.text('تعذّر تجهيز الصورة'), findsOneWidget);

    fakes.renderer.failCompose = false;
    fakes.renderer.prepareCompleter = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('share-retry')));
    await tester.pump();

    expect(skeletons, findsOneWidget);
    expect(find.byKey(const ValueKey('share-preview-image')), findsNothing);

    fakes.renderer.prepareCompleter!.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(skeletons, findsNothing);
    expect(find.byKey(const ValueKey('share-preview-image')), findsOneWidget);
  });

  testWidgets('a second tap on نص فقط while sharing starts no second share', (
    tester,
  ) async {
    final release = Completer<void>();
    var calls = 0;
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      calls++;
      await release.future;
      return 'dev.fluttercommunity.plus/share/success';
    });
    await open(tester);
    await tapVisible(tester, textButton());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tapVisible(tester, textButton());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(calls, 1);

    release.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tapVisible(tester, textButton());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(calls, 2);
  });

  group('controls are disabled until the card is ready', () {
    void expectDisabled(WidgetTester tester) {
      for (final paper in MushafPaper.values) {
        expect(
          tester
              .widget<InkResponse>(
                find.byKey(ValueKey('share-paper-${paper.name}')),
              )
              .onTap,
          isNull,
        );
      }
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('share-tafsir')))
            .onChanged,
        isNull,
      );
      expect(onPressed(tester, shareButton()), isNull);
      expect(
        tester
            .widget<AppSegmentedSelector<ShareFormat>>(
              find.byKey(const ValueKey('share-format')),
            )
            .enabled,
        isFalse,
      );
    }

    testWidgets('while loading', (tester) async {
      fakes.renderer.prepareCompleter = Completer<void>();
      await open(tester);
      expectDisabled(tester);
    });

    testWidgets('after a render failure', (tester) async {
      fakes.renderer.failCompose = true;
      await open(tester);
      expectDisabled(tester);
    });
  });

  testWidgets('fits at 2x text in 360 px', (tester) async {
    await open(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits at 2x text in 360 px with the tafsir failed', (
    tester,
  ) async {
    await open(tester, textScale: 2);
    await tapVisible(tester, find.byKey(const ValueKey('share-tafsir')));
    await tester.pump();
    fakes.tafsir.completers.single.complete(
      const Left(NotFoundFailure('6:31')),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('share-tafsir-retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('reel mode', () {
    const start = AyahIdentifier(surah: 6, ayah: 31);

    Future<void> tapKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }

    Future<void> chooseReel(WidgetTester tester, {String? label}) async {
      final finder = find.text(label ?? 'مقطع بالتلاوة');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      await pumpUntil(tester, () => fakes.framePainter.calls.isNotEmpty);
    }

    Future<void> addAyah(WidgetTester tester, int count) async {
      await tapKey(tester, 'reel-plus');
      await pumpUntil(tester, () => fakes.framePainter.calls.length >= count);
    }

    String countText(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('reel-count'))).data!;

    VoidCallback? iconPressed(WidgetTester tester, String key) =>
        tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed;

    String reelFile(String name) {
      final dir = Directory.systemTemp.createTempSync();
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/$name')..createSync();
      return file.path;
    }

    Future<void> startEncode(WidgetTester tester) async {
      fakes.composeReel.completer = Completer();
      await chooseReel(tester);
      await addAyah(tester, 2);
      await tester.ensureVisible(shareButton());
      await tester.tap(shareButton());
      await pumpUntil(
        tester,
        () => find.byKey(const ValueKey('reel-encoding')).evaluate().isNotEmpty,
      );
    }

    testWidgets('the selector offers صورة and مقطع بالتلاوة, image first', (
      tester,
    ) async {
      await open(tester);

      final selector = tester.widget<AppSegmentedSelector<ShareFormat>>(
        find.byKey(const ValueKey('share-format')),
      );
      expect(selector.options.map((o) => o.label), ['صورة', 'مقطع بالتلاوة']);
      expect(selector.selected, ShareFormat.image);
      expect(selector.enabled, isTrue);
      expect(find.byKey(const ValueKey('reel-plus')), findsNothing);
    });

    testWidgets('choosing the reel shows the stepper and the reciter', (
      tester,
    ) async {
      await open(tester);
      await chooseReel(tester);

      expect(find.text('بصوت ${Reciter.husary.arabicName}'), findsOneWidget);
      expect(countText(tester), '١');
      expect(iconPressed(tester, 'reel-minus'), isNull);
      expect(iconPressed(tester, 'reel-plus'), isNotNull);
      expect(fakes.prepareAudio.requests, [start]);
    });

    testWidgets('«+» adds an ayah and «−» removes it', (tester) async {
      await open(tester);
      await chooseReel(tester);
      await addAyah(tester, 2);

      expect(countText(tester), '٢');

      await tapKey(tester, 'reel-minus');
      await tester.pump();

      expect(countText(tester), '١');
    });

    testWidgets('a start ayah over 60 s shows the trim caption and no «+»', (
      tester,
    ) async {
      fakes.prepareAudio.durations[start] = const Duration(seconds: 75);
      await open(tester);
      await chooseReel(tester);

      expect(
        find.text('قد تقصّ بعض التطبيقات المقاطع الأطول من ٦٠ ثانية'),
        findsOneWidget,
      );
      expect(iconPressed(tester, 'reel-plus'), isNull);
    });

    testWidgets(
      'share encodes with progress, then shares the MP4 with the range label',
      (tester) async {
        await open(tester);
        await startEncode(tester);

        expect(fakes.composeReel.requests.single.clips, hasLength(2));
        fakes.composeReel.progressCtrl.add(0.5);
        await tester.pump();
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.descendant(
                  of: find.byKey(const ValueKey('reel-encoding')),
                  matching: find.byType(LinearProgressIndicator),
                ),
              )
              .value,
          0.5,
        );
        expect(find.text('جارٍ تجهيز المقطع'), findsOneWidget);

        final path = reelFile('ayah_6_31-32.mp4');
        fakes.composeReel.completer!.complete(Right(path));
        await pumpUntil(tester, () => shared.isNotEmpty);

        final args = shared.single;
        expect((args['paths'] as List).single, endsWith('ayah_6_31-32.mp4'));
        expect(args['mimeTypes'], ['video/mp4']);
        expect(
          args['text'],
          'سورة ${quran.getSurahNameArabic(6)}، الآيات ٣١–٣٢',
        );
      },
    );

    testWidgets('in English a reel shares the English range label', (
      tester,
    ) async {
      await open(tester, locale: const Locale('en'));
      fakes.composeReel.completer = Completer();
      await chooseReel(tester, label: 'Recitation clip');
      await addAyah(tester, 2);
      await tester.ensureVisible(find.widgetWithText(ActionBtn, 'Share'));
      await tester.tap(find.widgetWithText(ActionBtn, 'Share'));
      await pumpUntil(tester, () => fakes.composeReel.requests.isNotEmpty);
      final path = reelFile('ayah_6_31-32.mp4');
      fakes.composeReel.completer!.complete(Right(path));
      await pumpUntil(tester, () => shared.isNotEmpty);

      expect(
        shared.single['text'],
        'Surah ${quran.getSurahName(6)}, Ayat 31–32',
      );
    });

    testWidgets('cancel stops the encode without a message', (tester) async {
      await open(tester);
      await startEncode(tester);

      await tapKey(tester, 'reel-cancel');
      await pumpUntil(
        tester,
        () => find.byKey(const ValueKey('reel-encoding')).evaluate().isEmpty,
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(fakes.composeReel.cancels, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(onPressed(tester, shareButton()), isNotNull);
    });

    testWidgets('an encode failure shows the message with a retry', (
      tester,
    ) async {
      await open(tester);
      await startEncode(tester);
      fakes.composeReel.completer!.complete(const Left(UnknownFailure('x')));
      await pumpUntil(
        tester,
        () => find.byKey(const ValueKey('reel-retry')).evaluate().isNotEmpty,
      );

      expect(find.text('تعذّر تجهيز المقطع'), findsOneWidget);

      fakes.composeReel.completer = Completer();
      await tapKey(tester, 'reel-retry');
      await pumpUntil(tester, () => fakes.composeReel.requests.length == 2);

      expect(fakes.composeReel.requests, hasLength(2));
    });

    testWidgets('changing the reel hides the encode failure row', (
      tester,
    ) async {
      await open(tester);
      await startEncode(tester);
      fakes.composeReel.completer!.complete(const Left(UnknownFailure('x')));
      await pumpUntil(
        tester,
        () => find.byKey(const ValueKey('reel-retry')).evaluate().isNotEmpty,
      );

      await tapKey(tester, 'reel-minus');

      expect(find.byKey(const ValueKey('reel-retry')), findsNothing);
      expect(find.text('تعذّر تجهيز المقطع'), findsNothing);
    });

    testWidgets(
      'the preview shows the frame in reel mode and the card in image',
      (tester) async {
        await open(tester);
        final cardBytes = fakes.renderer.outputs.last;
        Uint8List? previewBytes() => tester
            .widget<ShareCardPreview>(find.byType(ShareCardPreview))
            .bytes;

        expect(previewBytes(), same(cardBytes));

        await chooseReel(tester);
        await pumpUntil(tester, () => previewBytes() != cardBytes);

        expect(previewBytes(), same(fakes.framePainter.outputs.last));

        await tester.ensureVisible(find.text('صورة'));
        await tester.tap(find.text('صورة'));
        await tester.pump();
        await pumpUntil(tester, () => fakes.renderer.outputs.length >= 2);

        expect(previewBytes(), same(fakes.renderer.outputs.last));
      },
    );

    testWidgets('the swatches and the tafsir switch are off while encoding', (
      tester,
    ) async {
      await open(tester);
      await startEncode(tester);

      expect(find.byKey(const ValueKey('reel-encoding')), findsOneWidget);
      expect(
        tester.widget<PaperSwatches>(find.byType(PaperSwatches)).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('share-tafsir')))
            .onChanged,
        isNull,
      );
    });

    testWidgets('a «+» that would pass 60 s explains the disabled «+»', (
      tester,
    ) async {
      fakes.prepareAudio.durations[start] = const Duration(seconds: 58);
      await open(tester);
      await chooseReel(tester);
      expect(find.text('الآية التالية تتجاوز ٦٠ ثانية'), findsNothing);

      await tapKey(tester, 'reel-plus');
      await pumpUntil(
        tester,
        () => find.text('الآية التالية تتجاوز ٦٠ ثانية').evaluate().isNotEmpty,
      );

      expect(find.text('الآية التالية تتجاوز ٦٠ ثانية'), findsOneWidget);
      expect(iconPressed(tester, 'reel-plus'), isNull);
      expect(countText(tester), '١');
    });

    testWidgets('a card failure on «+» says the card, not the recitation', (
      tester,
    ) async {
      await open(tester);
      await chooseReel(tester);
      fakes.renderer.failPrepare = true;

      await tapKey(tester, 'reel-plus');
      await pumpUntil(
        tester,
        () => find.byType(SnackBar).evaluate().isNotEmpty,
      );

      expect(find.text('تعذّر تجهيز الصورة'), findsOneWidget);
      expect(find.text('تعذّر تحميل التلاوة'), findsNothing);
    });

    testWidgets('an audio failure shows the SnackBar and keeps the image', (
      tester,
    ) async {
      fakes.prepareAudio.failing.add(start);
      await open(tester);
      await tester.ensureVisible(find.text('مقطع بالتلاوة'));
      await tester.tap(find.text('مقطع بالتلاوة'));
      await pumpUntil(
        tester,
        () => find.byType(SnackBar).evaluate().isNotEmpty,
      );

      expect(find.text('تعذّر تحميل التلاوة'), findsOneWidget);
      expect(
        tester
            .widget<AppSegmentedSelector<ShareFormat>>(
              find.byKey(const ValueKey('share-format')),
            )
            .selected,
        ShareFormat.image,
      );
      expect(onPressed(tester, shareButton()), isNotNull);
    });

    testWidgets('the audio SnackBar shows once', (tester) async {
      fakes.prepareAudio.failing.add(start);
      await open(tester);
      await tester.ensureVisible(find.text('مقطع بالتلاوة'));
      await tester.tap(find.text('مقطع بالتلاوة'));
      await pumpUntil(
        tester,
        () => find.byType(SnackBar).evaluate().isNotEmpty,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(SnackBar)),
      ).removeCurrentSnackBar();
      await tester.pump();

      await tester.ensureVisible(shareButton());
      await tester.tap(shareButton());
      await pumpUntil(tester, () => shared.isNotEmpty);

      expect(find.text('تعذّر تحميل التلاوة'), findsNothing);
    });

    testWidgets(
      'fits at 2x text in 360 px in reel mode with the trim caption',
      (tester) async {
        fakes.prepareAudio.durations[start] = const Duration(seconds: 75);
        await open(tester, textScale: 2);
        await chooseReel(tester);

        expect(find.byKey(const ValueKey('reel-plus')), findsOneWidget);
        expect(
          find.text('قد تقصّ بعض التطبيقات المقاطع الأطول من ٦٠ ثانية'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
