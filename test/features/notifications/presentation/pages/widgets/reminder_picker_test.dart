import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/reminder_picker.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../alerts_test_harness.dart';

void main() {
  late SettingsCubit settings;
  late List<int> commits;

  setUpAll(() => HydratedBloc.storage = MemStorage());
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    commits = [];
  });
  tearDown(() => settings.close());

  Future<void> pump(
    WidgetTester tester, {
    String? rawTime = '04:50',
    bool enabled = true,
  }) async {
    await tester.pumpWidget(
      alertsApp(
        settings: settings,
        home: Scaffold(
          body: ReminderPicker(
            minutes: 10,
            enabled: enabled,
            rawTime: rawTime,
            use24Hour: false,
            onCommit: commits.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the value with Arabic plural and the arrival time', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('قبل ١٠ دقائق'), findsOneWidget);
    expect(find.text('يصلك ٤:٤٠ ص'), findsOneWidget);
    expect(find.text('دقيقة واحدة'), findsOneWidget);
    expect(find.text('٦٠ دقيقة'), findsOneWidget);
  });

  testWidgets('a null arrival time hides the arrival line', (tester) async {
    await pump(tester, rawTime: null);
    expect(find.textContaining('يصلك'), findsNothing);
  });

  testWidgets('dragging the slider commits once on drag end', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(commits.length, 1);
    expect(commits.single, isNot(10));
    expect(find.text('قبل ١٠ دقائق'), findsNothing);
  });

  testWidgets('tapping a chip commits its value at once', (tester) async {
    await pump(tester);
    await tester.tap(find.text('٣٠ دقيقة'));
    await tester.pumpAndSettle();
    expect(commits, [30]);
    expect(find.text('قبل ٣٠ دقيقة'), findsOneWidget);
  });

  testWidgets('disabled picker ignores chips and the slider', (tester) async {
    await pump(tester, enabled: false);
    await tester.tap(find.text('٣٠ دقيقة'), warnIfMissed: false);
    await tester.drag(
      find.byType(Slider),
      const Offset(-120, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
  });

  testWidgets('the arrival time follows the slider while dragging', (
    tester,
  ) async {
    await pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(1000, 0));
    await tester.pump();
    final value = tester.widget<Text>(find.textContaining('قبل ')).data;
    final arrives = tester.widget<Text>(find.textContaining('يصلك')).data;
    expect(
      (value, arrives),
      anyOf(
        ('قبل دقيقة واحدة', 'يصلك ٤:٤٩ ص'),
        ('قبل ٦٠ دقيقة', 'يصلك ٣:٥٠ ص'),
      ),
    );
    expect(commits, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the slider announces minutes, not a percentage', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final node = find.semantics.byValue('١٠ دقائق');
    expect(node, findsOne);
    final data = node.evaluate().single.getSemanticsData();
    expect(data.increasedValue, '١١ دقيقة');
    expect(data.decreasedValue, '٩ دقائق');
    expect(find.semantics.byValue(RegExp('%')), findsNothing);
    handle.dispose();
  });
}
