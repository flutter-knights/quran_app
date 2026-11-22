import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/fasil_chooser.dart';
import 'package:quran_app/generated/l10n.dart';

Place place(FasilSlot slot, int surah, int ayah, {String? name}) => Place(
  id: slot.name,
  ayah: AyahIdentifier(surah: surah, ayah: ayah),
  page: quran.getPageNumber(surah, ayah),
  slot: slot,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  FasilChoice? result;
  var closed = false;

  setUp(() {
    result = null;
    closed = false;
  });

  Future<void> open(
    WidgetTester tester, {
    Map<FasilSlot, Place>? slots,
    AyahIdentifier? selected,
    FasilSlot? preselect,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final placed = slots ?? {FasilSlot.hifz: place(FasilSlot.hifz, 3, 6)};
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await FasilChooser.show(
                  context,
                  slots: placed,
                  selected: selected,
                  preselect: preselect,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder row(FasilSlot slot) => find.byKey(ValueKey('fasil-row-${slot.name}'));

  testWidgets('three rows in fixed order', (tester) async {
    await open(tester);
    final ys = [for (final s in FasilSlot.values) tester.getTopLeft(row(s)).dy];
    expect(ys[0], lessThan(ys[1]));
    expect(ys[1], lessThan(ys[2]));
    expect(
      find.descendant(
        of: row(FasilSlot.wird),
        matching: find.text('غير موضوع'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row(FasilSlot.muraja),
        matching: find.text('غير موضوع'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row(FasilSlot.hifz), matching: find.text('الحفظ')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row(FasilSlot.hifz),
        matching: find.text('آل عمران ٦، صفحة ٥٠'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a placed row goes there', (tester) async {
    final hifz = place(FasilSlot.hifz, 3, 6);
    await open(tester, slots: {FasilSlot.hifz: hifz});
    expect(find.byKey(const ValueKey('fasil-go-wird')), findsNothing);
    expect(find.byKey(const ValueKey('fasil-go-muraja')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fasil-go-hifz')));
    await tester.pumpAndSettle();
    expect(result, FasilGo(hifz));
    expect(closed, isTrue);
  });

  testWidgets('without a selection nothing moves', (tester) async {
    await open(tester);
    for (final s in FasilSlot.values) {
      expect(find.byKey(ValueKey('fasil-move-${s.name}')), findsNothing);
    }
  });

  testWidgets('a ribbon already on the selected ayah offers no move', (
    tester,
  ) async {
    await open(
      tester,
      selected: const AyahIdentifier(surah: 3, ayah: 6),
      preselect: FasilSlot.hifz,
    );
    expect(find.byKey(const ValueKey('fasil-move-hifz')), findsNothing);
    expect(find.byKey(const ValueKey('fasil-move-wird')), findsOneWidget);
  });

  testWidgets('with a selection placed rows move and unset rows place', (
    tester,
  ) async {
    await open(tester, selected: const AyahIdentifier(surah: 2, ayah: 5));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('fasil-move-hifz')),
        matching: find.text('نقل إلى هنا'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('fasil-move-wird')),
        matching: find.text('ضع هنا'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('fasil-move-wird')));
    await tester.pumpAndSettle();
    expect(result, const FasilMoveHere(FasilSlot.wird));
  });

  testWidgets('the preselected row names its slot and is the only filled '
      'button', (tester) async {
    await open(
      tester,
      selected: const AyahIdentifier(surah: 2, ayah: 5),
      preselect: FasilSlot.hifz,
    );
    final hifz = find.byKey(const ValueKey('fasil-move-hifz'));
    expect(hifz, findsOneWidget);
    expect(tester.widget(hifz), isA<FilledButton>());
    expect(find.text('نقل الحفظ إلى هنا'), findsOneWidget);
    expect(
      tester.widget(find.byKey(const ValueKey('fasil-move-wird'))),
      isA<OutlinedButton>(),
    );
    expect(
      tester.widget(find.byKey(const ValueKey('fasil-move-muraja'))),
      isA<OutlinedButton>(),
    );
  });

  testWidgets('screen readers hear which ribbon each button moves', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester, selected: const AyahIdentifier(surah: 2, ayah: 5));
    expect(find.bySemanticsLabel('ضع الورد هنا'), findsOneWidget);
    expect(find.bySemanticsLabel('ضع المراجعة هنا'), findsOneWidget);
    expect(find.bySemanticsLabel('نقل الحفظ إلى هنا'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a renamed slot shows its name', (tester) async {
    await open(
      tester,
      slots: {FasilSlot.hifz: place(FasilSlot.hifz, 3, 6, name: 'حفظ رمضان')},
    );
    expect(
      find.descendant(
        of: row(FasilSlot.hifz),
        matching: find.text('حفظ رمضان'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('fits at 2x text', (tester) async {
    await open(
      tester,
      selected: const AyahIdentifier(surah: 2, ayah: 5),
      preselect: FasilSlot.hifz,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
