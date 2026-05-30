import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/notification_hint.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeScheduler implements PrayerNotificationScheduler {
  _FakeScheduler(this.enabled);
  final bool enabled;
  @override
  Future<bool> areNotificationsEnabled() async => enabled;
  @override
  Future<void> init() async {}
  @override
  Future<bool?> requestNotificationsPermission() async => true;
  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes p) async {}
  @override
  Future<void> cancelAllPrayerNotifications() async {}
  @override
  Future<void> scheduleStaticReminder({
    required PrayerName prayer,
    required DateTime at,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancelAllStaticReminders() async {}
  @override
  Future<void> scheduleTestNotification({Duration delay = Duration.zero}) async {}
}

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

  testWidgets('hidden when notifications enabled', (tester) async {
    await tester.pumpWidget(host(NotificationHint(
      dismissed: false,
      onAllow: () async {},
      onDismiss: () {},
      scheduler: _FakeScheduler(true),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shown when disabled; dismiss fires callback', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(host(NotificationHint(
      dismissed: false,
      onAllow: () async {},
      onDismiss: () => dismissed = true,
      scheduler: _FakeScheduler(false),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });

  testWidgets('hidden when dismissed flag set', (tester) async {
    await tester.pumpWidget(host(NotificationHint(
      dismissed: true,
      onAllow: () async {},
      onDismiss: () {},
      scheduler: _FakeScheduler(false),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });
}
