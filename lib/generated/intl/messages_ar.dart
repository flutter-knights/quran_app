// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ar locale. All the
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
  String get localeName => 'ar';

  static String m0(weekday, day, month, year) =>
      "${weekday}، ${day} ${month} ${year} هـ";

  static String m1(time, prayerName) => "متبقي ${time} على صلاة ${prayerName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "abu_dawood": MessageLookupByLibrary.simpleMessage("سنن أبي داود"),
    "al_silsila_sahiha": MessageLookupByLibrary.simpleMessage(
      "السلسلة الصحيحة",
    ),
    "al_tirmidhi": MessageLookupByLibrary.simpleMessage("جامع الترمذي"),
    "arabicLanguage": MessageLookupByLibrary.simpleMessage("اللغة العربية"),
    "asr": MessageLookupByLibrary.simpleMessage("العصر"),
    "darkMode": MessageLookupByLibrary.simpleMessage("الوضع الداكن"),
    "dhuhr": MessageLookupByLibrary.simpleMessage("الظهر"),
    "fajr": MessageLookupByLibrary.simpleMessage("الفجر"),
    "hijriDateWithDay": m0,
    "ibn_e_majah": MessageLookupByLibrary.simpleMessage("سنن ابن ماجه"),
    "isha": MessageLookupByLibrary.simpleMessage("العشاء"),
    "maghrib": MessageLookupByLibrary.simpleMessage("المغرب"),
    "mishkat": MessageLookupByLibrary.simpleMessage("مشكاة المصابيح"),
    "musnad_ahmad": MessageLookupByLibrary.simpleMessage("مسند أحمد"),
    "remainingTimeLabel": m1,
    "sahih_bukhari": MessageLookupByLibrary.simpleMessage("صحيح البخاري"),
    "sahih_muslim": MessageLookupByLibrary.simpleMessage("صحيح مسلم"),
    "settings": MessageLookupByLibrary.simpleMessage("الإعدادات"),
    "sunan_nasai": MessageLookupByLibrary.simpleMessage("سنن النسائي"),
    "sunrise": MessageLookupByLibrary.simpleMessage("الشروق"),
    "twentyFourHourFormat": MessageLookupByLibrary.simpleMessage(
      "تنسيق 24 ساعة",
    ),
  };
}
