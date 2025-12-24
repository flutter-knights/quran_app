import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DateTimeFormatting on DateTime {
  String toReadableTime(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.jm(locale).format(this);
  }

  String to24hTime() {
    return DateFormat.Hm().format(this);
  }

  String format12h(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('hh:mm a', locale).format(this);
  }
}

abstract class TimeHelpers {
  static DateTime parse24hTime({required String time}) {
    final now = DateTime.now();
    final parts = time.split(':');

    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}
