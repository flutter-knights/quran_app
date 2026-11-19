import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/entities/prayer_countdown.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/upcoming_prayer.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../../../notifications/presentation/alerts_test_harness.dart';

class _MockCountdown extends MockCubit<PrayerCountdownState>
    implements PrayerCountdownCubit {}

void main() {
  late SettingsCubit settings;

  setUpAll(() => HydratedBloc.storage = MemStorage());
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    sl.registerSingleton<SettingsCubit>(settings);
  });
  tearDown(() async {
    await sl.unregister<SettingsCubit>();
    await settings.close();
  });

  Future<void> pump(WidgetTester tester, PrayerName next) async {
    final countdown = _MockCountdown();
    whenListen(
      countdown,
      const Stream<PrayerCountdownState>.empty(),
      initialState: PrayerCountdownTick(
        PrayerCountdown(
          currentPrayer: PrayerName.fajr,
          nextPrayer: next,
          remainingTime: const Duration(minutes: 12),
        ),
      ),
    );
    await tester.pumpWidget(
      alertsApp(
        settings: settings,
        home: BlocProvider<PrayerCountdownCubit>.value(
          value: countdown,
          child: const UpcomingPrayer(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sunrise is not called a prayer', (tester) async {
    await pump(tester, PrayerName.sunrise);
    expect(find.textContaining('على الشروق'), findsOneWidget);
    expect(find.textContaining('صلاة الشروق'), findsNothing);
  });

  testWidgets('a prayer keeps the prayer wording', (tester) async {
    await pump(tester, PrayerName.asr);
    expect(find.textContaining('على صلاة العصر'), findsOneWidget);
  });
}
