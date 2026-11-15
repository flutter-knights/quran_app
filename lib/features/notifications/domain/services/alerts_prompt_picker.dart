import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';

enum AlertsPrompt { upgrade, missed, late }

({AlertsPrompt prompt, PrayerName? prayer})? pickAlertsPrompt({
  required bool alertsIntroSeen,
  required bool onboardingComplete,
  required ReliabilityStatus status,
}) {
  if (!onboardingComplete) return null;
  if (!alertsIntroSeen) return (prompt: AlertsPrompt.upgrade, prayer: null);
  if (_latest(status.missed) case final prayer?) {
    return (prompt: AlertsPrompt.missed, prayer: prayer);
  }
  if (_latest(status.late) case final prayer?) {
    return (prompt: AlertsPrompt.late, prayer: prayer);
  }
  return null;
}

PrayerName? _latest(List<MissedAlert> alerts) => alerts.isEmpty
    ? null
    : alerts.reduce((a, b) => b.at.isAfter(a.at) ? b : a).prayer;
