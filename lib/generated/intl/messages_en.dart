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

  static String m0(count) => "${count} ahadith";

  static String m1(surah, ayah) => "Surah ${surah}, Ayah ${ayah}";

  static String m2(count) => "${count} books";

  static String m3(weekday, day, month, year) =>
      "${weekday}, ${day} ${month} ${year} AH";

  static String m4(page) => "Page ${page}";

  static String m5(percent) => "${percent}% complete";

  static String m6(time, prayerName) => "${time} remaining for ${prayerName}";

  static String m7(minutes) => "${minutes} min before";

  static String m8(count) => "${count} surahs";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "abu_dawood": MessageLookupByLibrary.simpleMessage("Sunan Abi Dawood"),
        "adhanPerPrayerSection":
            MessageLookupByLibrary.simpleMessage("Adhan per prayer"),
        "ahadith_count": m0,
        "ahadith_section": MessageLookupByLibrary.simpleMessage("Ahadith"),
        "al_silsila_sahiha":
            MessageLookupByLibrary.simpleMessage("Al-Silsila al-Sahiha"),
        "al_tirmidhi":
            MessageLookupByLibrary.simpleMessage("Jami\' al-Tirmidhi"),
        "all_surahs": MessageLookupByLibrary.simpleMessage("All Surahs"),
        "appearance_section":
            MessageLookupByLibrary.simpleMessage("Appearance"),
        "arabicLanguage":
            MessageLookupByLibrary.simpleMessage("Arabic Language"),
        "arabic_label": MessageLookupByLibrary.simpleMessage("Arabic"),
        "asr": MessageLookupByLibrary.simpleMessage("Asr"),
        "author_abu_dawood": MessageLookupByLibrary.simpleMessage(
            "Imam Abu Dawood al-Sijistani"),
        "author_ahmad":
            MessageLookupByLibrary.simpleMessage("Imam Ahmad ibn Hanbal"),
        "author_albani": MessageLookupByLibrary.simpleMessage(
            "Muhammad Nasiruddin al-Albani"),
        "author_bukhari": MessageLookupByLibrary.simpleMessage(
            "Imam Muhammad ibn Isma\'il al-Bukhari"),
        "author_ibn_majah": MessageLookupByLibrary.simpleMessage(
            "Imam Muhammad ibn Yazid Ibn Majah al-Qazwini"),
        "author_mishkat":
            MessageLookupByLibrary.simpleMessage("Imam al-Khatib al-Tabrizi"),
        "author_muslim": MessageLookupByLibrary.simpleMessage(
            "Imam Muslim ibn al-Hajjaj al-Naysaburi"),
        "author_nasai": MessageLookupByLibrary.simpleMessage(
            "Imam Ahmad ibn Shu\'ayb al-Nasa\'i"),
        "author_tirmidhi": MessageLookupByLibrary.simpleMessage(
            "Imam Muhammad ibn \'Isa al-Tirmidhi"),
        "ayah_label": m1,
        "bookmark": MessageLookupByLibrary.simpleMessage("Bookmark"),
        "bookmark_added": MessageLookupByLibrary.simpleMessage("Bookmarked"),
        "bookmark_removed":
            MessageLookupByLibrary.simpleMessage("Bookmark removed"),
        "bookmark_save_failed":
            MessageLookupByLibrary.simpleMessage("Couldn\'t save bookmark"),
        "bookmarks_screen_title":
            MessageLookupByLibrary.simpleMessage("Bookmarks"),
        "books_count": m2,
        "books_section": MessageLookupByLibrary.simpleMessage("Books"),
        "chapter_label": MessageLookupByLibrary.simpleMessage("Chapter"),
        "collections_label":
            MessageLookupByLibrary.simpleMessage("Collections"),
        "coming_soon": MessageLookupByLibrary.simpleMessage("Coming soon"),
        "continue_reading":
            MessageLookupByLibrary.simpleMessage("Continue reading"),
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
        "full_title_abu_dawood":
            MessageLookupByLibrary.simpleMessage("Sunan Abi Dawood"),
        "full_title_ahmad": MessageLookupByLibrary.simpleMessage(
            "Musnad Imam Ahmad ibn Hanbal"),
        "full_title_albani": MessageLookupByLibrary.simpleMessage(
            "The Series of Authentic Hadith"),
        "full_title_bukhari": MessageLookupByLibrary.simpleMessage(
            "The Abridged Authentic Collection"),
        "full_title_ibn_majah":
            MessageLookupByLibrary.simpleMessage("Sunan Ibn Majah"),
        "full_title_mishkat":
            MessageLookupByLibrary.simpleMessage("Mishkat al-Masabih"),
        "full_title_muslim": MessageLookupByLibrary.simpleMessage(
            "The Authentic Musnad (Abridged)"),
        "full_title_nasai":
            MessageLookupByLibrary.simpleMessage("Sunan an-Nasa\'i"),
        "full_title_tirmidhi":
            MessageLookupByLibrary.simpleMessage("Jami\' al-Tirmidhi"),
        "general_section": MessageLookupByLibrary.simpleMessage("General"),
        "hadith_books_appbar_title":
            MessageLookupByLibrary.simpleMessage("Hadith Books"),
        "hadith_heading_label":
            MessageLookupByLibrary.simpleMessage("Hadith Heading"),
        "hadith_number_label":
            MessageLookupByLibrary.simpleMessage("Hadith No."),
        "hadith_screen_title": MessageLookupByLibrary.simpleMessage("Hadith"),
        "hadith_total_label":
            MessageLookupByLibrary.simpleMessage("Total Ahadith"),
        "hijriDateWithDay": m3,
        "ibn_e_majah": MessageLookupByLibrary.simpleMessage("Sunan Ibn Majah"),
        "isha": MessageLookupByLibrary.simpleMessage("Isha"),
        "lastRead": MessageLookupByLibrary.simpleMessage("Last Read"),
        "madaniyya": MessageLookupByLibrary.simpleMessage("Madaniyya"),
        "maghrib": MessageLookupByLibrary.simpleMessage("Maghrib"),
        "makkiyya": MessageLookupByLibrary.simpleMessage("Makkiyya"),
        "mishkat": MessageLookupByLibrary.simpleMessage("Mishkat al-Masabih"),
        "musnad_ahmad": MessageLookupByLibrary.simpleMessage("Musnad Ahmad"),
        "narrator_label": MessageLookupByLibrary.simpleMessage("Narrator"),
        "next_hadith": MessageLookupByLibrary.simpleMessage("Next"),
        "notifications": MessageLookupByLibrary.simpleMessage("Notifications"),
        "notificationsScreenSubtitle": MessageLookupByLibrary.simpleMessage(
            "Manage prayer-time notifications."),
        "page_label": m4,
        "pinnedPrayerTimes":
            MessageLookupByLibrary.simpleMessage("Pinned prayer times"),
        "pinnedPrayerTimesSubtitle": MessageLookupByLibrary.simpleMessage(
            "Show today\'s prayers in your notification shade."),
        "play": MessageLookupByLibrary.simpleMessage("Play"),
        "playTestAdhan":
            MessageLookupByLibrary.simpleMessage("Play test adhan"),
        "play_surah": MessageLookupByLibrary.simpleMessage("Play surah"),
        "playback_close": MessageLookupByLibrary.simpleMessage("Close"),
        "playback_next": MessageLookupByLibrary.simpleMessage("Next ayah"),
        "playback_pause": MessageLookupByLibrary.simpleMessage("Pause"),
        "playback_previous":
            MessageLookupByLibrary.simpleMessage("Previous ayah"),
        "playback_restart": MessageLookupByLibrary.simpleMessage("Restart"),
        "playback_speed": MessageLookupByLibrary.simpleMessage("Speed"),
        "prayers": MessageLookupByLibrary.simpleMessage("Prayers"),
        "progress_complete": m5,
        "quickAccess": MessageLookupByLibrary.simpleMessage("Quick Access"),
        "quran_screen_title": MessageLookupByLibrary.simpleMessage("Quran"),
        "reciter_label": MessageLookupByLibrary.simpleMessage("Reciter"),
        "remainingTimeLabel": m6,
        "reminderLabel": MessageLookupByLibrary.simpleMessage("Remind me"),
        "reminderMinutesBefore": m7,
        "reminderOff": MessageLookupByLibrary.simpleMessage("Off"),
        "sahih_bukhari":
            MessageLookupByLibrary.simpleMessage("Sahih al-Bukhari"),
        "sahih_muslim": MessageLookupByLibrary.simpleMessage("Sahih Muslim"),
        "search_surah_hint":
            MessageLookupByLibrary.simpleMessage("Search for a surah..."),
        "settings": MessageLookupByLibrary.simpleMessage("Settings"),
        "settings_screen_title":
            MessageLookupByLibrary.simpleMessage("Settings"),
        "share": MessageLookupByLibrary.simpleMessage("Share"),
        "share_failed":
            MessageLookupByLibrary.simpleMessage("Couldn\'t open share sheet"),
        "status_daeef": MessageLookupByLibrary.simpleMessage("Da\'eef"),
        "status_hasan": MessageLookupByLibrary.simpleMessage("Hasan"),
        "status_mudu": MessageLookupByLibrary.simpleMessage("Maudu\'"),
        "status_sahih": MessageLookupByLibrary.simpleMessage("Sahih"),
        "sunan_nasai": MessageLookupByLibrary.simpleMessage("Sunan an-Nasa\'i"),
        "sunrise": MessageLookupByLibrary.simpleMessage("Sunrise"),
        "surahs_appbar_title": MessageLookupByLibrary.simpleMessage("Surahs"),
        "surahs_count": m8,
        "tafsir": MessageLookupByLibrary.simpleMessage("Tafsir"),
        "testAdhanScheduledSnack":
            MessageLookupByLibrary.simpleMessage("Test adhan in 5 seconds"),
        "the_noble_quran":
            MessageLookupByLibrary.simpleMessage("The Noble Qur\'an"),
        "translation": MessageLookupByLibrary.simpleMessage("Translation"),
        "translation_label":
            MessageLookupByLibrary.simpleMessage("Translation"),
        "twentyFourHourFormat":
            MessageLookupByLibrary.simpleMessage("24-Hour Format")
      };
}
