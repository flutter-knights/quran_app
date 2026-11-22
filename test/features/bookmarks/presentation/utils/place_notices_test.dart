import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/place_notices.dart';
import 'package:quran_app/generated/l10n.dart';

Future<void> _show(
  WidgetTester tester, {
  required bool talkBack,
  VoidCallback? onUndo,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(accessibleNavigation: talkBack);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        S.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlaceNotice(
              ScaffoldMessenger.of(context),
              'حُفظت',
              onUndo: onUndo,
            ),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
  expect(find.byType(SnackBar), findsOneWidget);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('undo stays until dismissed while TalkBack is on', (
    tester,
  ) async {
    await _show(tester, talkBack: true, onUndo: () {});
    expect(find.text('تراجع'), findsOneWidget);
  });

  testWidgets('undo leaves by itself without TalkBack', (tester) async {
    await _show(tester, talkBack: false, onUndo: () {});
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a notice without undo leaves by itself under TalkBack', (
    tester,
  ) async {
    await _show(tester, talkBack: true);
    expect(find.byType(SnackBar), findsNothing);
  });
}
