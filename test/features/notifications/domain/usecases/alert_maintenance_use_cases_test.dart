import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/ack_missed_alerts.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_reliability_status.dart';
import 'package:quran_app/features/notifications/domain/usecases/open_system_settings.dart';
import 'package:quran_app/features/notifications/domain/usecases/preview_alert_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/schedule_test_adhan.dart';
import 'package:quran_app/features/notifications/domain/usecases/stop_alert_preview.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  test('GetReliabilityStatus returns the repository status', () async {
    const status = ReliabilityStatus.ios(notificationsEnabled: true);
    when(
      () => repo.getReliabilityStatus(),
    ).thenAnswer((_) async => const Right(status));
    expect(
      await GetReliabilityStatus(repository: repo)(NoParams()),
      const Right(status),
    );
  });

  test('AckMissedAlerts passes upTo', () async {
    final upTo = DateTime(2026, 11, 15, 12);
    when(
      () => repo.ackMissedAlerts(upTo: upTo),
    ).thenAnswer((_) async => const Right(unit));
    await AckMissedAlerts(repository: repo)(AckMissedAlertsParams(upTo: upTo));
    verify(() => repo.ackMissedAlerts(upTo: upTo)).called(1);
  });

  test('OpenSystemSettings passes the target', () async {
    when(
      () => repo.openSystemSettings(SystemSettingsTarget.autostart),
    ).thenAnswer((_) async => const Right(unit));
    await OpenSystemSettings(repository: repo)(SystemSettingsTarget.autostart);
    verify(
      () => repo.openSystemSettings(SystemSettingsTarget.autostart),
    ).called(1);
  });

  test('PreviewAlertSound passes sound and prayer', () async {
    when(
      () =>
          repo.previewSound(sound: PreviewSound.adhan, prayer: PrayerName.fajr),
    ).thenAnswer((_) async => const Right(unit));
    await PreviewAlertSound(repository: repo)(
      const PreviewAlertSoundParams(
        sound: PreviewSound.adhan,
        prayer: PrayerName.fajr,
      ),
    );
    verify(
      () =>
          repo.previewSound(sound: PreviewSound.adhan, prayer: PrayerName.fajr),
    ).called(1);
  });

  test('StopAlertPreview delegates to stopPreview', () async {
    when(() => repo.stopPreview()).thenAnswer((_) async => const Right(unit));
    await StopAlertPreview(repository: repo)(NoParams());
    verify(() => repo.stopPreview()).called(1);
  });

  test('ScheduleTestAdhan passes the alert and locale', () async {
    const alert = PrayerAlert(sound: PrayerSound.vibrate);
    when(
      () => repo.scheduleTestAdhan(alert: alert, localeCode: 'ar'),
    ).thenAnswer((_) async => const Right(unit));
    await ScheduleTestAdhan(repository: repo)(
      const ScheduleTestAdhanParams(alert: alert, localeCode: 'ar'),
    );
    verify(
      () => repo.scheduleTestAdhan(alert: alert, localeCode: 'ar'),
    ).called(1);
  });
}
