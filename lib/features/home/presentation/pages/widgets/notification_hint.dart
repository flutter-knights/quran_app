import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/generated/l10n.dart';

/// Slim, dismissible Home hint shown only when notifications are OS-disabled
/// and the user hasn't dismissed it. [onAllow] should request permission and
/// then trigger a context re-fetch (which reschedules adhans); [onDismiss]
/// persists the dismissal. [dismissed] reflects the settings flag.
class NotificationHint extends StatefulWidget {
  const NotificationHint({
    super.key,
    required this.dismissed,
    required this.onAllow,
    required this.onDismiss,
    this.scheduler,
  });

  final bool dismissed;
  final Future<void> Function() onAllow;
  final VoidCallback onDismiss;
  final PrayerNotificationScheduler? scheduler;

  @override
  State<NotificationHint> createState() => _NotificationHintState();
}

class _NotificationHintState extends State<NotificationHint>
    with WidgetsBindingObserver {
  bool _enabled = true; // assume enabled until checked (hides by default)

  PrayerNotificationScheduler get _scheduler =>
      widget.scheduler ?? sl<PrayerNotificationScheduler>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final enabled = await _scheduler.areNotificationsEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {/* leave hidden on error */}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dismissed || _enabled) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    final s = S.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedNotification01,
            color: scheme.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.home_notifHint_text,
              style: TS.regular14.copyWith(color: scheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () async {
              await widget.onAllow();
              await _refresh();
            },
            child: Text(s.home_notifHint_allow),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: scheme.onSurface),
            onPressed: widget.onDismiss,
          ),
        ],
      ),
    );
  }
}
