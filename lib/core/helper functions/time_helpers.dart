import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DateTimeFormatting on DateTime {
  String to24hTime() {
    return DateFormat.Hm().format(this);
  }

  String format12h(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('hh:mm a', locale).format(this);
  }
}

extension StringTimes on String {
  DateTime parse24hTime({DateTime? date}) {
    final now = date ?? DateTime.now();
    final parts = split(':');

    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  String removeTimeZone() {
    return split(' ').first;
  }

  DateTime gregorianDate() {
    final format = DateFormat('dd-MM-yyyy');
    return format.parse(this);
  }
}
