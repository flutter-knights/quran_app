// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(weekday, day, month, year) =>
      "${weekday}, ${day} ${month} ${year} AH";

  static String m1(time, prayerName) => "${time} remaining for ${prayerName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "abu_dawood": MessageLookupByLibrary.simpleMessage("Sunan Abu Dawood"),
    "al_silsila_sahiha": MessageLookupByLibrary.simpleMessage(
      "Al-Silsila Sahiha",
    ),
    "al_tirmidhi": MessageLookupByLibrary.simpleMessage("Jami\' Al-Tirmidhi"),
    "arabicLanguage": MessageLookupByLibrary.simpleMessage("Arabic Language"),
    "asr": MessageLookupByLibrary.simpleMessage("Asr"),
    "darkMode": MessageLookupByLibrary.simpleMessage("Dark Mode"),
    "dhuhr": MessageLookupByLibrary.simpleMessage("Dhuhr"),
    "fajr": MessageLookupByLibrary.simpleMessage("Fajr"),
    "hijriDateWithDay": m0,
    "ibn_e_majah": MessageLookupByLibrary.simpleMessage("Sunan Ibn-e-Majah"),
    "isha": MessageLookupByLibrary.simpleMessage("Isha"),
    "maghrib": MessageLookupByLibrary.simpleMessage("Maghrib"),
    "mishkat": MessageLookupByLibrary.simpleMessage("Mishkat Al-Masabih"),
    "musnad_ahmad": MessageLookupByLibrary.simpleMessage("Musnad Ahmad"),
    "remainingTimeLabel": m1,
    "sahih_bukhari": MessageLookupByLibrary.simpleMessage("Sahih Bukhari"),
    "sahih_muslim": MessageLookupByLibrary.simpleMessage("Sahih Muslim"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "sunan_nasai": MessageLookupByLibrary.simpleMessage("Sunan An-Nasa\'i"),
    "sunrise": MessageLookupByLibrary.simpleMessage("Sunrise"),
    "twentyFourHourFormat": MessageLookupByLibrary.simpleMessage(
      "24-Hour Format",
    ),
  };
}
