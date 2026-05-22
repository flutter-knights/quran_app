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

  static String m2(surah, ayah) => "Surah ${surah}, Ayah ${ayah}";

  static String m3(page) => "Page ${page}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "abu_dawood": MessageLookupByLibrary.simpleMessage("Sunan Abi Dawood"),
    "al_silsila_sahiha": MessageLookupByLibrary.simpleMessage(
      "Al-Silsila al-Sahiha",
    ),
    "al_tirmidhi": MessageLookupByLibrary.simpleMessage("Jami\' al-Tirmidhi"),
    "arabicLanguage": MessageLookupByLibrary.simpleMessage("Arabic Language"),
    "arabic_label": MessageLookupByLibrary.simpleMessage("Arabic"),
    "asr": MessageLookupByLibrary.simpleMessage("Asr"),
    "author_abu_dawood": MessageLookupByLibrary.simpleMessage(
      "Imam Abu Dawood al-Sijistani",
    ),
    "author_ahmad": MessageLookupByLibrary.simpleMessage(
      "Imam Ahmad ibn Hanbal",
    ),
    "author_albani": MessageLookupByLibrary.simpleMessage(
      "Imam Muhammad Nasiruddin al-Albani",
    ),
    "author_bukhari": MessageLookupByLibrary.simpleMessage(
      "Imam Muhammad ibn Isma\'il al-Bukhari",
    ),
    "author_ibn_majah": MessageLookupByLibrary.simpleMessage(
      "Imam Muhammad ibn Yazid Ibn Majah al-Qazwini",
    ),
    "author_mishkat": MessageLookupByLibrary.simpleMessage(
      "Imam al-Khatib al-Tabrizi",
    ),
    "author_muslim": MessageLookupByLibrary.simpleMessage(
      "Imam Muslim ibn al-Hajjaj al-Naysaburi",
    ),
    "author_nasai": MessageLookupByLibrary.simpleMessage(
      "Imam Ahmad ibn Shu\'ayb al-Nasa\'i",
    ),
    "author_tirmidhi": MessageLookupByLibrary.simpleMessage(
      "Imam Muhammad ibn \'Isa al-Tirmidhi",
    ),
    "chapter_label": MessageLookupByLibrary.simpleMessage("Chapter"),
    "darkMode": MessageLookupByLibrary.simpleMessage("Dark Mode"),
    "death_abu_dawood": MessageLookupByLibrary.simpleMessage("275 AH"),
    "death_ahmad": MessageLookupByLibrary.simpleMessage("241 AH"),
    "death_albani": MessageLookupByLibrary.simpleMessage("1420 AH"),
    "death_bukhari": MessageLookupByLibrary.simpleMessage("256 AH"),
    "death_ibn_majah": MessageLookupByLibrary.simpleMessage("273 AH"),
    "death_mishkat": MessageLookupByLibrary.simpleMessage("741 AH"),
    "death_muslim": MessageLookupByLibrary.simpleMessage("261 AH"),
    "death_nasai": MessageLookupByLibrary.simpleMessage("303 AH"),
    "death_tirmidhi": MessageLookupByLibrary.simpleMessage("279 AH"),
    "dhuhr": MessageLookupByLibrary.simpleMessage("Dhuhr"),
    "fajr": MessageLookupByLibrary.simpleMessage("Fajr"),
    "full_title_abu_dawood": MessageLookupByLibrary.simpleMessage(
      "Sunan Abi Dawood",
    ),
    "full_title_ahmad": MessageLookupByLibrary.simpleMessage(
      "Musnad Imam Ahmad ibn Hanbal",
    ),
    "full_title_albani": MessageLookupByLibrary.simpleMessage(
      "The Series of Authentic Hadith",
    ),
    "full_title_bukhari": MessageLookupByLibrary.simpleMessage(
      "The Abridged Authentic Collection",
    ),
    "full_title_ibn_majah": MessageLookupByLibrary.simpleMessage(
      "Sunan Ibn Majah",
    ),
    "full_title_mishkat": MessageLookupByLibrary.simpleMessage(
      "Mishkat al-Masabih",
    ),
    "full_title_muslim": MessageLookupByLibrary.simpleMessage(
      "The Authentic Musnad (Abridged)",
    ),
    "full_title_nasai": MessageLookupByLibrary.simpleMessage(
      "Sunan an-Nasa\'i",
    ),
    "full_title_tirmidhi": MessageLookupByLibrary.simpleMessage(
      "Jami\' al-Tirmidhi",
    ),
    "hadith_heading_label": MessageLookupByLibrary.simpleMessage(
      "Hadith Heading",
    ),
    "hadith_number_label": MessageLookupByLibrary.simpleMessage("Hadith No."),
    "hadith_total_label": MessageLookupByLibrary.simpleMessage("Total Ahadith"),
    "hijriDateWithDay": m0,
    "ibn_e_majah": MessageLookupByLibrary.simpleMessage("Sunan Ibn Majah"),
    "isha": MessageLookupByLibrary.simpleMessage("Isha"),
    "maghrib": MessageLookupByLibrary.simpleMessage("Maghrib"),
    "mishkat": MessageLookupByLibrary.simpleMessage("Mishkat al-Masabih"),
    "musnad_ahmad": MessageLookupByLibrary.simpleMessage("Musnad Ahmad"),
    "remainingTimeLabel": m1,
    "sahih_bukhari": MessageLookupByLibrary.simpleMessage("Sahih al-Bukhari"),
    "sahih_muslim": MessageLookupByLibrary.simpleMessage("Sahih Muslim"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "status_daeef": MessageLookupByLibrary.simpleMessage("Da\'eef"),
    "status_hasan": MessageLookupByLibrary.simpleMessage("Hasan"),
    "status_mudu": MessageLookupByLibrary.simpleMessage("Maudu\'"),
    "status_sahih": MessageLookupByLibrary.simpleMessage("Sahih"),
    "sunan_nasai": MessageLookupByLibrary.simpleMessage("Sunan an-Nasa\'i"),
    "sunrise": MessageLookupByLibrary.simpleMessage("Sunrise"),
    "translation_label": MessageLookupByLibrary.simpleMessage("Translation"),
    "twentyFourHourFormat": MessageLookupByLibrary.simpleMessage(
      "24-Hour Format",
    ),
    "tafsir": MessageLookupByLibrary.simpleMessage("Tafsir"),
    "translation": MessageLookupByLibrary.simpleMessage("Translation"),
    "play": MessageLookupByLibrary.simpleMessage("Play"),
    "bookmark": MessageLookupByLibrary.simpleMessage("Bookmark"),
    "share": MessageLookupByLibrary.simpleMessage("Share"),
    "coming_soon": MessageLookupByLibrary.simpleMessage("Coming soon"),
    "bookmark_added": MessageLookupByLibrary.simpleMessage("Bookmarked"),
    "bookmark_removed": MessageLookupByLibrary.simpleMessage(
      "Bookmark removed",
    ),
    "bookmark_save_failed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t save bookmark",
    ),
    "share_failed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t open share sheet",
    ),
    "playback_pause": MessageLookupByLibrary.simpleMessage("Pause"),
    "playback_next": MessageLookupByLibrary.simpleMessage("Next ayah"),
    "playback_previous": MessageLookupByLibrary.simpleMessage("Previous ayah"),
    "playback_restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "playback_close": MessageLookupByLibrary.simpleMessage("Close"),
    "playback_speed": MessageLookupByLibrary.simpleMessage("Speed"),
    "reciter_label": MessageLookupByLibrary.simpleMessage("Reciter"),
    "continue_reading": MessageLookupByLibrary.simpleMessage(
      "Continue reading",
    ),
    "ayah_label": m2,
    "page_label": m3,
    "play_surah": MessageLookupByLibrary.simpleMessage("Play surah"),
    "pinnedPrayerTimes": MessageLookupByLibrary.simpleMessage("Pinned prayer times"),
    "pinnedPrayerTimesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Show today\'s prayers in your notification shade.",
    ),
  };
}
