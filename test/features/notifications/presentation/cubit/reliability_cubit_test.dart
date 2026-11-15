import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/domain/usecases/ack_missed_alerts.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_reliability_status.dart';
import 'package:quran_app/features/notifications/domain/usecases/open_system_settings.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';

class _MockGet extends Mock implements GetReliabilityStatus {}

class _MockAck extends Mock implements AckMissedAlerts {}

class _MockOpen extends Mock implements OpenSystemSettings {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockGet get;
  late _MockAck ack;
  late _MockOpen open;

  const status = ReliabilityStatus(
    notificationsEnabled: true,
    channelBlocked: false,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
    isXiaomi: false,
    usesAlarmClock: true,
  );
  final ishaMiss = MissedAlert(
    prayer: PrayerName.isha,
    at: DateTime(2026, 11, 14, 18, 16),
  );
  final asrLate = MissedAlert(
    prayer: PrayerName.asr,
    at: DateTime(2026, 11, 15, 14, 39),
  );
  final withMissAndLate = status.copyWith(missed: [ishaMiss], late: [asrLate]);

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(AckMissedAlertsParams(upTo: DateTime(2000)));
    registerFallbackValue(SystemSettingsTarget.notifications);
  });

  setUp(() {
    get = _MockGet();
    ack = _MockAck();
    open = _MockOpen();
    when(() => get(any())).thenAnswer((_) async => const Right(status));
    when(() => ack(any())).thenAnswer((_) async => const Right(unit));
    when(() => open(any())).thenAnswer((_) async => const Right(unit));
  });

  ReliabilityCubit build() => ReliabilityCubit(get, ack, open);

  blocTest<ReliabilityCubit, ReliabilityState>(
    'loads on create',
    build: build,
    expect: () => [const ReliabilityLoaded(status)],
  );

  blocTest<ReliabilityCubit, ReliabilityState>(
    'failure emits unavailable',
    setUp: () => when(
      () => get(any()),
    ).thenAnswer((_) async => const Left(UnknownNotificationFailure('x'))),
    build: build,
    expect: () => [const ReliabilityUnavailable()],
  );

  blocTest<ReliabilityCubit, ReliabilityState>(
    'ackMissed acks up to the newest shown alert then reloads',
    build: build,
    act: (c) => c.ackMissed(withMissAndLate),
    verify: (_) {
      final params =
          verify(() => ack(captureAny())).captured.single
              as AckMissedAlertsParams;
      expect(params.upTo, asrLate.at);
      verify(() => get(any())).called(2);
    },
  );

  blocTest<ReliabilityCubit, ReliabilityState>(
    'ackMissed with nothing shown does not ack',
    build: build,
    act: (c) => c.ackMissed(status),
    verify: (_) => verifyNever(() => ack(any())),
  );

  blocTest<ReliabilityCubit, ReliabilityState>(
    'openSettings forwards the target',
    build: build,
    act: (c) => c.openSettings(SystemSettingsTarget.battery),
    verify: (_) => verify(() => open(SystemSettingsTarget.battery)).called(1),
  );
}
