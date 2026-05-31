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

  static String m2(count) => "${count} ayahs";

  static String m3(count) => "${count} books";

  static String m4(number) => "Go to Juzʼ ${number}";

  static String m5(number) => "Go to page ${number}";

  static String m6(weekday, day, month, year) =>
      "${weekday}, ${day} ${month} ${year} AH";

  static String m7(number) => "Juzʼ ${number}";

  static String m8(page) => "Page ${page}";

  static String m9(percent) => "${percent}% complete";

  static String m10(time, prayerName) => "${time} remaining for ${prayerName}";

  static String m11(minutes) => "${minutes} min before";

  static String m12(count) => "+${count} more — refine your search";

  static String m13(surah, ayah) => "${surah} · Ayah ${ayah}";

  static String m14(count) => "${count} surahs";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "abu_dawood": MessageLookupByLibrary.simpleMessage("Sunan Abi Dawood"),
        "adhanPerPrayerSection":
            MessageLookupByLibrary.simpleMessage("Adhan per prayer"),
        "adhan_and_reminders":
            MessageLookupByLibrary.simpleMessage("Adhan & Reminders"),
        "ahadith_count": m0,
        "ahadith_section": MessageLookupByLibrary.simpleMessage("Ahadith"),
        "al_silsila_sahiha":
            MessageLookupByLibrary.simpleMessage("Al-Silsila al-Sahiha"),
        "al_tirmidhi":
            MessageLookupByLibrary.simpleMessage("Jami\' al-Tirmidhi"),
        "all_juz": MessageLookupByLibrary.simpleMessage("All Juzʼ"),
        "all_surahs": MessageLookupByLibrary.simpleMessage("All Surahs"),
        "app_name": MessageLookupByLibrary.simpleMessage("Al-Furqan"),
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
        "ayahs_count": m2,
        "bookmark": MessageLookupByLibrary.simpleMessage("Bookmark"),
        "bookmark_added": MessageLookupByLibrary.simpleMessage("Bookmarked"),
        "bookmark_removed":
            MessageLookupByLibrary.simpleMessage("Bookmark removed"),
        "bookmark_save_failed":
            MessageLookupByLibrary.simpleMessage("Couldn\'t save bookmark"),
        "bookmarks_ahadith_section":
            MessageLookupByLibrary.simpleMessage("Ahadith"),
        "bookmarks_quran_section":
            MessageLookupByLibrary.simpleMessage("Quran"),
        "bookmarks_screen_title":
            MessageLookupByLibrary.simpleMessage("Bookmarks"),
        "bookmarks_title": MessageLookupByLibrary.simpleMessage("Bookmarks"),
        "books_count": m3,
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
        "filter_all_chapters":
            MessageLookupByLibrary.simpleMessage("All chapters"),
        "filter_apply": MessageLookupByLibrary.simpleMessage("Apply"),
        "filter_chapter_label": MessageLookupByLibrary.simpleMessage("Chapter"),
        "filter_clear": MessageLookupByLibrary.simpleMessage("Clear"),
        "filter_status_label": MessageLookupByLibrary.simpleMessage("Status"),
        "filters_title": MessageLookupByLibrary.simpleMessage("Filters"),
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
        "go_to_juz": m4,
        "go_to_page": m5,
        "hadith_books_appbar_title":
            MessageLookupByLibrary.simpleMessage("Hadith Books"),
        "hadith_heading_label":
            MessageLookupByLibrary.simpleMessage("Hadith Heading"),
        "hadith_number_label":
            MessageLookupByLibrary.simpleMessage("Hadith No."),
        "hadith_of_the_day":
            MessageLookupByLibrary.simpleMessage("Hadith of the Day"),
        "hadith_screen_title": MessageLookupByLibrary.simpleMessage("Hadith"),
        "hadith_total_label":
            MessageLookupByLibrary.simpleMessage("Total Ahadith"),
        "hijriDateWithDay": m6,
        "ibn_e_majah": MessageLookupByLibrary.simpleMessage("Sunan Ibn Majah"),
        "isha": MessageLookupByLibrary.simpleMessage("Isha"),
        "jump_to_page_header":
            MessageLookupByLibrary.simpleMessage("Go to page"),
        "jumuah": MessageLookupByLibrary.simpleMessage("Jumu\'ah"),
        "juz_label": m7,
        "language_arabic": MessageLookupByLibrary.simpleMessage("العربية"),
        "language_english": MessageLookupByLibrary.simpleMessage("English"),
        "lastRead": MessageLookupByLibrary.simpleMessage("Last Read"),
        "madaniyya": MessageLookupByLibrary.simpleMessage("Madaniyya"),
        "maghrib": MessageLookupByLibrary.simpleMessage("Maghrib"),
        "makkiyya": MessageLookupByLibrary.simpleMessage("Makkiyya"),
        "mishkat": MessageLookupByLibrary.simpleMessage("Mishkat al-Masabih"),
        "musnad_ahmad": MessageLookupByLibrary.simpleMessage("Musnad Ahmad"),
        "narrator_label": MessageLookupByLibrary.simpleMessage("Narrator"),
        "next_hadith": MessageLookupByLibrary.simpleMessage("Next"),
        "no_bookmarks_yet":
            MessageLookupByLibrary.simpleMessage("No bookmarks yet"),
        "notifications": MessageLookupByLibrary.simpleMessage("Notifications"),
        "notificationsScreenSubtitle": MessageLookupByLibrary.simpleMessage(
            "Manage prayer-time notifications."),
        "onb_appearance_title":
            MessageLookupByLibrary.simpleMessage("Personalize your look"),
        "onb_continue": MessageLookupByLibrary.simpleMessage("Continue"),
        "onb_enable": MessageLookupByLibrary.simpleMessage("Enable"),
        "onb_language_hint":
            MessageLookupByLibrary.simpleMessage("You can change it later"),
        "onb_language_title":
            MessageLookupByLibrary.simpleMessage("Choose your language"),
        "onb_location_title": MessageLookupByLibrary.simpleMessage(
            "Your prayer times, precisely"),
        "onb_location_why": MessageLookupByLibrary.simpleMessage(
            "We use your location to calculate accurate prayer times for your city. It stays on your device and is never shared."),
        "onb_not_now": MessageLookupByLibrary.simpleMessage("Not now"),
        "onb_notifications_title":
            MessageLookupByLibrary.simpleMessage("Never miss a prayer"),
        "onb_notifications_why": MessageLookupByLibrary.simpleMessage(
            "Allow notifications to receive the adhan and prayer reminders on time. You can fine-tune them later in settings."),
        "onb_splash_desc": MessageLookupByLibrary.simpleMessage(
            "Each time you open the app from now on"),
        "onb_theme_label": MessageLookupByLibrary.simpleMessage("Theme"),
        "onb_time_format_label":
            MessageLookupByLibrary.simpleMessage("Time format"),
        "onb_welcome_headline": MessageLookupByLibrary.simpleMessage(
            "The Noble Qur\'an, in your hands"),
        "onb_welcome_subtitle": MessageLookupByLibrary.simpleMessage(
            "Read, listen, and reflect — with your prayer times in one place."),
        "page_label": m8,
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
        "previous_hadith": MessageLookupByLibrary.simpleMessage("Previous"),
        "progress_complete": m9,
        "quickAccess": MessageLookupByLibrary.simpleMessage("Quick Access"),
        "quran_screen_title": MessageLookupByLibrary.simpleMessage("Quran"),
        "quran_search_no_results":
            MessageLookupByLibrary.simpleMessage("No results"),
        "reciter_label": MessageLookupByLibrary.simpleMessage("Reciter"),
        "remainingTimeLabel": m10,
        "reminderLabel": MessageLookupByLibrary.simpleMessage("Remind me"),
        "reminderMinutesBefore": m11,
        "reminderOff": MessageLookupByLibrary.simpleMessage("Off"),
        "sahih_bukhari":
            MessageLookupByLibrary.simpleMessage("Sahih al-Bukhari"),
        "sahih_muslim": MessageLookupByLibrary.simpleMessage("Sahih Muslim"),
        "search_hadith_hint":
            MessageLookupByLibrary.simpleMessage("Search this book…"),
        "search_more_results": m12,
        "search_no_results":
            MessageLookupByLibrary.simpleMessage("No matching ahadith"),
        "search_quran_hint": MessageLookupByLibrary.simpleMessage(
            "Search surah, juzʼ, page, or ayah…"),
        "search_section_ayahs": MessageLookupByLibrary.simpleMessage("Ayahs"),
        "search_section_surahs": MessageLookupByLibrary.simpleMessage("Surahs"),
        "search_surah_hint":
            MessageLookupByLibrary.simpleMessage("Search for a surah..."),
        "settings": MessageLookupByLibrary.simpleMessage("Settings"),
        "settings_screen_title":
            MessageLookupByLibrary.simpleMessage("Settings"),
        "share": MessageLookupByLibrary.simpleMessage("Share"),
        "share_failed":
            MessageLookupByLibrary.simpleMessage("Couldn\'t open share sheet"),
        "show_splash_screen":
            MessageLookupByLibrary.simpleMessage("Splash screen"),
        "start_reading": MessageLookupByLibrary.simpleMessage("Start reading"),
        "start_reading_subtitle":
            MessageLookupByLibrary.simpleMessage("Begin with Al-Fatiha"),
        "status_daeef": MessageLookupByLibrary.simpleMessage("Da\'eef"),
        "status_hasan": MessageLookupByLibrary.simpleMessage("Hasan"),
        "status_mudu": MessageLookupByLibrary.simpleMessage("Maudu\'"),
        "status_sahih": MessageLookupByLibrary.simpleMessage("Sahih"),
        "sunan_nasai": MessageLookupByLibrary.simpleMessage("Sunan an-Nasa\'i"),
        "sunrise": MessageLookupByLibrary.simpleMessage("Sunrise"),
        "surah_ayah_label": m13,
        "surahs_appbar_title": MessageLookupByLibrary.simpleMessage("Mushaf"),
        "surahs_count": m14,
        "tab_juz": MessageLookupByLibrary.simpleMessage("Juzʼ"),
        "tab_pages": MessageLookupByLibrary.simpleMessage("Pages"),
        "tab_surahs": MessageLookupByLibrary.simpleMessage("Surahs"),
        "tafsir": MessageLookupByLibrary.simpleMessage("Tafsir"),
        "testAdhanScheduledSnack":
            MessageLookupByLibrary.simpleMessage("Test adhan in 5 seconds"),
        "test_section": MessageLookupByLibrary.simpleMessage("Test"),
        "the_noble_quran":
            MessageLookupByLibrary.simpleMessage("The Noble Qur\'an"),
        "time_format_12h": MessageLookupByLibrary.simpleMessage("12h"),
        "time_format_24h": MessageLookupByLibrary.simpleMessage("24h"),
        "translation": MessageLookupByLibrary.simpleMessage("Translation"),
        "translation_label":
            MessageLookupByLibrary.simpleMessage("Translation"),
        "twentyFourHourFormat":
            MessageLookupByLibrary.simpleMessage("24-Hour Format")
      };
}
