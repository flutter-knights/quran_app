import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/widgets/design/action_buttons_row.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/ayah_share_sheet.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../ayah_share_fakes.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _shareFailed = 'تعذّر فتح نافذة المشاركة';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FakeAyahShare fakes;
  late List<Map<Object?, Object?>> shared;
  var shareThrows = false;

  setUp(() {
    shareThrows = false;
    shared = [];
    fakes = registerFakeAyahShare();
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      if (shareThrows) throw PlatformException(code: 'unavailable');
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'dev.fluttercommunity.plus/share/success';
    });
    final temp = Directory.systemTemp.createTempSync().path;
    messenger.setMockMethodCallHandler(
      _pathChannel,
      (call) async => call.method == 'getTemporaryDirectory' ? temp : null,
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
      MaterialApp(
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
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !done(); i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
  }

  final skeletons = find.byWidgetPredicate((w) => w is Skeletonizer);

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
    expect(image.image, isA<MemoryImage>());
    expect((image.image as MemoryImage).bytes, onePixelPng);
    expect(skeletons, findsNothing);
  });

  testWidgets('the tafsir switch loads it and keeps the plain card shareable', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('share-tafsir')));
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

  testWidgets('a tafsir failure shows the message with a retry', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('share-tafsir')));
    await tester.pump();
    fakes.tafsir.completers.single.complete(
      const Left(NotFoundFailure('6:31')),
    );
    await tester.pump();

    expect(find.text('تعذّر تحميل التفسير'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share-tafsir-retry')));
    await tester.pump();

    expect(fakes.tafsir.completers, hasLength(2));
  });

  testWidgets('a paper swatch recomposes on that paper', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('share-paper-night')));
    await tester.pump();
    await tester.pump();

    expect(
      fakes.renderer.composeCalls.last.colors.background,
      MushafPaper.night.colors.background,
    );
  });

  testWidgets('share hands the PNG with its name and the ayah label', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(shareButton());
    await pumpUntil(tester, () => shared.isNotEmpty);

    final args = shared.single;
    expect((args['paths'] as List).single, endsWith('ayah_6_31.png'));
    expect(args['mimeTypes'], ['image/png']);
    expect(args['text'], 'سورة الأنعام، الآية ٣١');
    expect(args['originWidth'] as double, greaterThan(0));
  });

  testWidgets('in English the share text is the English label', (tester) async {
    await open(tester, locale: const Locale('en'));
    await tester.tap(find.widgetWithText(ActionBtn, 'Share'));
    await pumpUntil(tester, () => shared.isNotEmpty);

    expect(shared.single['text'], 'Surah ${quran.getSurahName(6)}, Ayah 31');
  });

  testWidgets('a failing share shows the message above the sheet', (
    tester,
  ) async {
    await open(tester);
    shareThrows = true;
    await tester.tap(shareButton());
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
    await tester.tap(textButton());
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
    await tester.tap(textButton());
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
    await tester.tap(find.byKey(const ValueKey('share-paper-night')));
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

  testWidgets('fits at 2x text in 360 px', (tester) async {
    await open(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
