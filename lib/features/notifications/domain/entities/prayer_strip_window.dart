import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_render_style.dart';

/// A bounded window of consecutive day-states sent to the native strip in one
/// payload. The native side stores the window and renders whichever day is
/// "today", so the strip survives day rollover without the app being reopened.
class PrayerStripWindow extends Equatable {
  final List<PrayerStripState> days;
  final StripRenderStyle? style;
  final String nextTag;

  const PrayerStripWindow({required this.days, this.style, this.nextTag = ''});

  Map<String, Object> toJson() => {
    'days': days.map((d) => d.toJson()).toList(),
    if (style != null) 'style': style!.toJson(),
    'nextTag': nextTag,
  };

  @override
  List<Object?> get props => [days, style, nextTag];
}
