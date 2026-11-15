import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/services/alerts_prompt_picker.dart';

void main() {
  const none = ReliabilityStatus.ios(notificationsEnabled: true);
  final miss = MissedAlert(
    prayer: PrayerName.isha,
    at: DateTime(2026, 11, 14, 18, 16),
  );
  final olderMiss = MissedAlert(
    prayer: PrayerName.maghrib,
    at: DateTime(2026, 11, 14, 16, 59),
  );
  final late = MissedAlert(
    prayer: PrayerName.asr,
    at: DateTime(2026, 11, 15, 14, 39),
  );

  test('upgrade first when intro unseen and onboarding complete', () {
    expect(
      pickAlertsPrompt(
        alertsIntroSeen: false,
        onboardingComplete: true,
        status: none.copyWith(missed: [miss]),
      ),
      (prompt: AlertsPrompt.upgrade, prayer: null),
    );
  });

  test('no upgrade before onboarding completes', () {
    expect(
      pickAlertsPrompt(
        alertsIntroSeen: false,
        onboardingComplete: false,
        status: none,
      ),
      isNull,
    );
  });

  test('missed beats late and names the most recent miss', () {
    expect(
      pickAlertsPrompt(
        alertsIntroSeen: true,
        onboardingComplete: true,
        status: none.copyWith(missed: [olderMiss, miss], late: [late]),
      ),
      (prompt: AlertsPrompt.missed, prayer: PrayerName.isha),
    );
  });

  test('late only', () {
    expect(
      pickAlertsPrompt(
        alertsIntroSeen: true,
        onboardingComplete: true,
        status: none.copyWith(late: [late]),
      ),
      (prompt: AlertsPrompt.late, prayer: PrayerName.asr),
    );
  });

  test('nothing to show', () {
    expect(
      pickAlertsPrompt(
        alertsIntroSeen: true,
        onboardingComplete: true,
        status: none,
      ),
      isNull,
    );
  });
}
