import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// A bounded window of consecutive day-states sent to the native strip in one
/// payload. The native side stores the window and renders whichever day is
/// "today", so the strip survives day rollover without the app being reopened.
class PrayerStripWindow extends Equatable {
  final List<PrayerStripState> days;

  const PrayerStripWindow({required this.days});

  Map<String, Object> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
      };

  @override
  List<Object?> get props => [days];
}
