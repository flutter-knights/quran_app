import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/notification_hint.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeScheduler implements PrayerNotificationScheduler {
  _FakeScheduler(this.enabled);
  bool enabled;
  @override
  Future<bool> areNotificationsEnabled() async => enabled;
  @override
  Future<void> init() async {}
  @override
  Future<bool?> requestNotificationsPermission() async => true;
  @override
  Future<DateTime?> scheduleAlerts({
    required List<PrayerTimes> days,
    required Map<PrayerName, PrayerAlert> alerts,
    required String localeCode,
  }) async => null;
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> scheduleTestNotification({
    required PrayerAlert alert,
    required String localeCode,
    Duration delay = Duration.zero,
  }) async {}
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
    await tester.pumpWidget(
      host(
        NotificationHint(
          hidden: false,
          onAllow: () async {},
          onOpenSettings: () async {},
          onDismiss: () {},
          scheduler: _FakeScheduler(true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shown when disabled; dismiss fires callback', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      host(
        NotificationHint(
          hidden: false,
          onAllow: () async {},
          onOpenSettings: () async {},
          onDismiss: () => dismissed = true,
          scheduler: _FakeScheduler(false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });

  testWidgets('hidden when dismissed flag set', (tester) async {
    await tester.pumpWidget(
      host(
        NotificationHint(
          hidden: true,
          onAllow: () async {},
          onOpenSettings: () async {},
          onDismiss: () {},
          scheduler: _FakeScheduler(false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('allow that leaves notifications off opens the settings', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        NotificationHint(
          hidden: false,
          onAllow: () async {},
          onOpenSettings: () async => opened++,
          onDismiss: () {},
          scheduler: _FakeScheduler(false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('allow that grants hides the hint without opening settings', (
    tester,
  ) async {
    var opened = 0;
    final scheduler = _FakeScheduler(false);
    await tester.pumpWidget(
      host(
        NotificationHint(
          hidden: false,
          onAllow: () async => scheduler.enabled = true,
          onOpenSettings: () async => opened++,
          onDismiss: () {},
          scheduler: scheduler,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.byType(TextButton), findsNothing);
  });
}
