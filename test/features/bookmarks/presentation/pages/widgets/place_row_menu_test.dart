import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/place_row_menu.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  var removed = 0;

  setUp(() => removed = 0);

  Future<void> pumpMenu(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: Center(child: PlaceRowMenu(onRemove: () => removed++)),
      ),
    ),
  );

  testWidgets('opens a menu with إزالة that calls onRemove', (tester) async {
    await pumpMenu(tester);
    expect(find.text('إزالة'), findsNothing);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('إزالة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('place-remove')));
    await tester.pumpAndSettle();

    expect(removed, 1);
    expect(find.text('إزالة'), findsNothing);
  });

  testWidgets('the button is at least 48 by 48', (tester) async {
    await pumpMenu(tester);

    final size = tester.getSize(find.byType(IconButton));

    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.byTooltip('خيارات'), findsOneWidget);
  });
}
