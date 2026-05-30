import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/location_recovery_card.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('renders action label and fires onAction', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(
      LocationRecoveryCard(
        actionLabel: 'Enable location',
        onAction: () => tapped = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Enable location'), findsOneWidget);
    await tester.tap(find.text('Enable location'));
    expect(tapped, isTrue);
  });
}
