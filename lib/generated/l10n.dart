// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Fajr`
  String get fajr {
    return Intl.message(
      'Fajr',
      name: 'fajr',
      desc: '',
      args: [],
    );
  }

  /// `Sunrise`
  String get sunrise {
    return Intl.message(
      'Sunrise',
      name: 'sunrise',
      desc: '',
      args: [],
    );
  }

  /// `Dhuhr`
  String get dhuhr {
    return Intl.message(
      'Dhuhr',
      name: 'dhuhr',
      desc: '',
      args: [],
    );
  }

  /// `Asr`
  String get asr {
    return Intl.message(
      'Asr',
      name: 'asr',
      desc: '',
      args: [],
    );
  }

  /// `Maghrib`
  String get maghrib {
    return Intl.message(
      'Maghrib',
      name: 'maghrib',
      desc: '',
      args: [],
    );
  }

  /// `Isha`
  String get isha {
    return Intl.message(
      'Isha',
      name: 'isha',
      desc: '',
      args: [],
    );
  }

  /// `{time} remaining for {prayerName}`
  String remainingTimeLabel(Object time, Object prayerName) {
    return Intl.message(
      '$time remaining for $prayerName',
      name: 'remainingTimeLabel',
      desc: '',
      args: [time, prayerName],
    );
  }

  /// `{weekday}, {day} {month} {year} AH`
  String hijriDateWithDay(
      Object weekday, Object day, Object month, Object year) {
    return Intl.message(
      '$weekday, $day $month $year AH',
      name: 'hijriDateWithDay',
      desc: '',
      args: [weekday, day, month, year],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: '',
      args: [],
    );
  }

  /// `Dark Mode`
  String get darkMode {
    return Intl.message(
      'Dark Mode',
      name: 'darkMode',
      desc: '',
      args: [],
    );
  }

  /// `24-Hour Format`
  String get twentyFourHourFormat {
    return Intl.message(
      '24-Hour Format',
      name: 'twentyFourHourFormat',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Language`
  String get arabicLanguage {
    return Intl.message(
      'Arabic Language',
      name: 'arabicLanguage',
      desc: '',
      args: [],
    );
  }

  /// `Pinned prayer times`
  String get pinnedPrayerTimes {
    return Intl.message(
      'Pinned prayer times',
      name: 'pinnedPrayerTimes',
      desc: '',
      args: [],
    );
  }

  /// `Show today's prayers in your notification shade.`
  String get pinnedPrayerTimesSubtitle {
    return Intl.message(
      'Show today\'s prayers in your notification shade.',
      name: 'pinnedPrayerTimesSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Notifications`
  String get notifications {
    return Intl.message(
      'Notifications',
      name: 'notifications',
      desc: '',
      args: [],
    );
  }

  /// `Manage prayer-time notifications.`
  String get notificationsScreenSubtitle {
    return Intl.message(
      'Manage prayer-time notifications.',
      name: 'notificationsScreenSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Hadith No.`
  String get hadith_number_label {
    return Intl.message(
      'Hadith No.',
      name: 'hadith_number_label',
      desc: '',
      args: [],
    );
  }

  /// `Total Ahadith`
  String get hadith_total_label {
    return Intl.message(
      'Total Ahadith',
      name: 'hadith_total_label',
      desc: '',
      args: [],
    );
  }

  /// `Hadith Heading`
  String get hadith_heading_label {
    return Intl.message(
      'Hadith Heading',
      name: 'hadith_heading_label',
      desc: '',
      args: [],
    );
  }

  /// `Arabic`
  String get arabic_label {
    return Intl.message(
      'Arabic',
      name: 'arabic_label',
      desc: '',
      args: [],
    );
  }

  /// `Translation`
  String get translation_label {
    return Intl.message(
      'Translation',
      name: 'translation_label',
      desc: '',
      args: [],
    );
  }

  /// `Chapter`
  String get chapter_label {
    return Intl.message(
      'Chapter',
      name: 'chapter_label',
      desc: '',
      args: [],
    );
  }

  /// `Sahih`
  String get status_sahih {
    return Intl.message(
      'Sahih',
      name: 'status_sahih',
      desc: '',
      args: [],
    );
  }

  /// `Hasan`
  String get status_hasan {
    return Intl.message(
      'Hasan',
      name: 'status_hasan',
      desc: '',
      args: [],
    );
  }

  /// `Da'eef`
  String get status_daeef {
    return Intl.message(
      'Da\'eef',
      name: 'status_daeef',
      desc: '',
      args: [],
    );
  }

  /// `Maudu'`
  String get status_mudu {
    return Intl.message(
      'Maudu\'',
      name: 'status_mudu',
      desc: '',
      args: [],
    );
  }

  /// `Sahih al-Bukhari`
  String get sahih_bukhari {
    return Intl.message(
      'Sahih al-Bukhari',
      name: 'sahih_bukhari',
      desc: '',
      args: [],
    );
  }

  /// `Sahih Muslim`
  String get sahih_muslim {
    return Intl.message(
      'Sahih Muslim',
      name: 'sahih_muslim',
      desc: '',
      args: [],
    );
  }

  /// `Jami' al-Tirmidhi`
  String get al_tirmidhi {
    return Intl.message(
      'Jami\' al-Tirmidhi',
      name: 'al_tirmidhi',
      desc: '',
      args: [],
    );
  }

  /// `Sunan Abi Dawood`
  String get abu_dawood {
    return Intl.message(
      'Sunan Abi Dawood',
      name: 'abu_dawood',
      desc: '',
      args: [],
    );
  }

  /// `Sunan Ibn Majah`
  String get ibn_e_majah {
    return Intl.message(
      'Sunan Ibn Majah',
      name: 'ibn_e_majah',
      desc: '',
      args: [],
    );
  }

  /// `Sunan an-Nasa'i`
  String get sunan_nasai {
    return Intl.message(
      'Sunan an-Nasa\'i',
      name: 'sunan_nasai',
      desc: '',
      args: [],
    );
  }

  /// `Mishkat al-Masabih`
  String get mishkat {
    return Intl.message(
      'Mishkat al-Masabih',
      name: 'mishkat',
      desc: '',
      args: [],
    );
  }

  /// `Musnad Ahmad`
  String get musnad_ahmad {
    return Intl.message(
      'Musnad Ahmad',
      name: 'musnad_ahmad',
      desc: '',
      args: [],
    );
  }

  /// `Al-Silsila al-Sahiha`
  String get al_silsila_sahiha {
    return Intl.message(
      'Al-Silsila al-Sahiha',
      name: 'al_silsila_sahiha',
      desc: '',
      args: [],
    );
  }

  /// `Imam Muhammad ibn Isma'il al-Bukhari`
  String get author_bukhari {
    return Intl.message(
      'Imam Muhammad ibn Isma\'il al-Bukhari',
      name: 'author_bukhari',
      desc: '',
      args: [],
    );
  }

  /// `256 AH`
  String get death_bukhari {
    return Intl.message(
      '256 AH',
      name: 'death_bukhari',
      desc: '',
      args: [],
    );
  }

  /// `The Abridged Authentic Collection`
  String get full_title_bukhari {
    return Intl.message(
      'The Abridged Authentic Collection',
      name: 'full_title_bukhari',
      desc: '',
      args: [],
    );
  }

  /// `Imam Muslim ibn al-Hajjaj al-Naysaburi`
  String get author_muslim {
    return Intl.message(
      'Imam Muslim ibn al-Hajjaj al-Naysaburi',
      name: 'author_muslim',
      desc: '',
      args: [],
    );
  }

  /// `261 AH`
  String get death_muslim {
    return Intl.message(
      '261 AH',
      name: 'death_muslim',
      desc: '',
      args: [],
    );
  }

  /// `The Authentic Musnad (Abridged)`
  String get full_title_muslim {
    return Intl.message(
      'The Authentic Musnad (Abridged)',
      name: 'full_title_muslim',
      desc: '',
      args: [],
    );
  }

  /// `Imam Muhammad ibn 'Isa al-Tirmidhi`
  String get author_tirmidhi {
    return Intl.message(
      'Imam Muhammad ibn \'Isa al-Tirmidhi',
      name: 'author_tirmidhi',
      desc: '',
      args: [],
    );
  }

  /// `279 AH`
  String get death_tirmidhi {
    return Intl.message(
      '279 AH',
      name: 'death_tirmidhi',
      desc: '',
      args: [],
    );
  }

  /// `Jami' al-Tirmidhi`
  String get full_title_tirmidhi {
    return Intl.message(
      'Jami\' al-Tirmidhi',
      name: 'full_title_tirmidhi',
      desc: '',
      args: [],
    );
  }

  /// `Imam Abu Dawood al-Sijistani`
  String get author_abu_dawood {
    return Intl.message(
      'Imam Abu Dawood al-Sijistani',
      name: 'author_abu_dawood',
      desc: '',
      args: [],
    );
  }

  /// `275 AH`
  String get death_abu_dawood {
    return Intl.message(
      '275 AH',
      name: 'death_abu_dawood',
      desc: '',
      args: [],
    );
  }

  /// `Sunan Abi Dawood`
  String get full_title_abu_dawood {
    return Intl.message(
      'Sunan Abi Dawood',
      name: 'full_title_abu_dawood',
      desc: '',
      args: [],
    );
  }

  /// `Imam Muhammad ibn Yazid Ibn Majah al-Qazwini`
  String get author_ibn_majah {
    return Intl.message(
      'Imam Muhammad ibn Yazid Ibn Majah al-Qazwini',
      name: 'author_ibn_majah',
      desc: '',
      args: [],
    );
  }

  /// `273 AH`
  String get death_ibn_majah {
    return Intl.message(
      '273 AH',
      name: 'death_ibn_majah',
      desc: '',
      args: [],
    );
  }

  /// `Sunan Ibn Majah`
  String get full_title_ibn_majah {
    return Intl.message(
      'Sunan Ibn Majah',
      name: 'full_title_ibn_majah',
      desc: '',
      args: [],
    );
  }

  /// `Imam Ahmad ibn Shu'ayb al-Nasa'i`
  String get author_nasai {
    return Intl.message(
      'Imam Ahmad ibn Shu\'ayb al-Nasa\'i',
      name: 'author_nasai',
      desc: '',
      args: [],
    );
  }

  /// `303 AH`
  String get death_nasai {
    return Intl.message(
      '303 AH',
      name: 'death_nasai',
      desc: '',
      args: [],
    );
  }

  /// `Sunan an-Nasa'i`
  String get full_title_nasai {
    return Intl.message(
      'Sunan an-Nasa\'i',
      name: 'full_title_nasai',
      desc: '',
      args: [],
    );
  }

  /// `Imam al-Khatib al-Tabrizi`
  String get author_mishkat {
    return Intl.message(
      'Imam al-Khatib al-Tabrizi',
      name: 'author_mishkat',
      desc: '',
      args: [],
    );
  }

  /// `741 AH`
  String get death_mishkat {
    return Intl.message(
      '741 AH',
      name: 'death_mishkat',
      desc: '',
      args: [],
    );
  }

  /// `Mishkat al-Masabih`
  String get full_title_mishkat {
    return Intl.message(
      'Mishkat al-Masabih',
      name: 'full_title_mishkat',
      desc: '',
      args: [],
    );
  }

  /// `Imam Ahmad ibn Hanbal`
  String get author_ahmad {
    return Intl.message(
      'Imam Ahmad ibn Hanbal',
      name: 'author_ahmad',
      desc: '',
      args: [],
    );
  }

  /// `241 AH`
  String get death_ahmad {
    return Intl.message(
      '241 AH',
      name: 'death_ahmad',
      desc: '',
      args: [],
    );
  }

  /// `Musnad Imam Ahmad ibn Hanbal`
  String get full_title_ahmad {
    return Intl.message(
      'Musnad Imam Ahmad ibn Hanbal',
      name: 'full_title_ahmad',
      desc: '',
      args: [],
    );
  }

  /// `Muhammad Nasiruddin al-Albani`
  String get author_albani {
    return Intl.message(
      'Muhammad Nasiruddin al-Albani',
      name: 'author_albani',
      desc: '',
      args: [],
    );
  }

  /// `1420 AH`
  String get death_albani {
    return Intl.message(
      '1420 AH',
      name: 'death_albani',
      desc: '',
      args: [],
    );
  }

  /// `The Series of Authentic Hadith`
  String get full_title_albani {
    return Intl.message(
      'The Series of Authentic Hadith',
      name: 'full_title_albani',
      desc: '',
      args: [],
    );
  }

  /// `Tafsir`
  String get tafsir {
    return Intl.message(
      'Tafsir',
      name: 'tafsir',
      desc: '',
      args: [],
    );
  }

  /// `Translation`
  String get translation {
    return Intl.message(
      'Translation',
      name: 'translation',
      desc: '',
      args: [],
    );
  }

  /// `Play`
  String get play {
    return Intl.message(
      'Play',
      name: 'play',
      desc: '',
      args: [],
    );
  }

  /// `Bookmark`
  String get bookmark {
    return Intl.message(
      'Bookmark',
      name: 'bookmark',
      desc: '',
      args: [],
    );
  }

  /// `Share`
  String get share {
    return Intl.message(
      'Share',
      name: 'share',
      desc: '',
      args: [],
    );
  }

  /// `Coming soon`
  String get coming_soon {
    return Intl.message(
      'Coming soon',
      name: 'coming_soon',
      desc: '',
      args: [],
    );
  }

  /// `Bookmarked`
  String get bookmark_added {
    return Intl.message(
      'Bookmarked',
      name: 'bookmark_added',
      desc: '',
      args: [],
    );
  }

  /// `Bookmark removed`
  String get bookmark_removed {
    return Intl.message(
      'Bookmark removed',
      name: 'bookmark_removed',
      desc: '',
      args: [],
    );
  }

  /// `Couldn't save bookmark`
  String get bookmark_save_failed {
    return Intl.message(
      'Couldn\'t save bookmark',
      name: 'bookmark_save_failed',
      desc: '',
      args: [],
    );
  }

  /// `Couldn't open share sheet`
  String get share_failed {
    return Intl.message(
      'Couldn\'t open share sheet',
      name: 'share_failed',
      desc: '',
      args: [],
    );
  }

  /// `Pause`
  String get playback_pause {
    return Intl.message(
      'Pause',
      name: 'playback_pause',
      desc: '',
      args: [],
    );
  }

  /// `Next ayah`
  String get playback_next {
    return Intl.message(
      'Next ayah',
      name: 'playback_next',
      desc: '',
      args: [],
    );
  }

  /// `Previous ayah`
  String get playback_previous {
    return Intl.message(
      'Previous ayah',
      name: 'playback_previous',
      desc: '',
      args: [],
    );
  }

  /// `Restart`
  String get playback_restart {
    return Intl.message(
      'Restart',
      name: 'playback_restart',
      desc: '',
      args: [],
    );
  }

  /// `Close`
  String get playback_close {
    return Intl.message(
      'Close',
      name: 'playback_close',
      desc: '',
      args: [],
    );
  }

  /// `Speed`
  String get playback_speed {
    return Intl.message(
      'Speed',
      name: 'playback_speed',
      desc: '',
      args: [],
    );
  }

  /// `Reciter`
  String get reciter_label {
    return Intl.message(
      'Reciter',
      name: 'reciter_label',
      desc: '',
      args: [],
    );
  }

  /// `Continue reading`
  String get continue_reading {
    return Intl.message(
      'Continue reading',
      name: 'continue_reading',
      desc: '',
      args: [],
    );
  }

  /// `Surah {surah}, Ayah {ayah}`
  String ayah_label(Object surah, Object ayah) {
    return Intl.message(
      'Surah $surah, Ayah $ayah',
      name: 'ayah_label',
      desc: '',
      args: [surah, ayah],
    );
  }

  /// `Page {page}`
  String page_label(Object page) {
    return Intl.message(
      'Page $page',
      name: 'page_label',
      desc: '',
      args: [page],
    );
  }

  /// `Play surah`
  String get play_surah {
    return Intl.message(
      'Play surah',
      name: 'play_surah',
      desc: '',
      args: [],
    );
  }

  /// `Adhan per prayer`
  String get adhanPerPrayerSection {
    return Intl.message(
      'Adhan per prayer',
      name: 'adhanPerPrayerSection',
      desc: '',
      args: [],
    );
  }

  /// `Remind me`
  String get reminderLabel {
    return Intl.message(
      'Remind me',
      name: 'reminderLabel',
      desc: '',
      args: [],
    );
  }

  /// `Off`
  String get reminderOff {
    return Intl.message(
      'Off',
      name: 'reminderOff',
      desc: '',
      args: [],
    );
  }

  /// `{minutes} min before`
  String reminderMinutesBefore(int minutes) {
    return Intl.message(
      '$minutes min before',
      name: 'reminderMinutesBefore',
      desc: '',
      args: [minutes],
    );
  }

  /// `Play test adhan`
  String get playTestAdhan {
    return Intl.message(
      'Play test adhan',
      name: 'playTestAdhan',
      desc: '',
      args: [],
    );
  }

  /// `Test adhan in 5 seconds`
  String get testAdhanScheduledSnack {
    return Intl.message(
      'Test adhan in 5 seconds',
      name: 'testAdhanScheduledSnack',
      desc: '',
      args: [],
    );
  }

  /// `Prayers`
  String get prayers {
    return Intl.message(
      'Prayers',
      name: 'prayers',
      desc: '',
      args: [],
    );
  }

  /// `Last Read`
  String get lastRead {
    return Intl.message(
      'Last Read',
      name: 'lastRead',
      desc: '',
      args: [],
    );
  }

  /// `Quick Access`
  String get quickAccess {
    return Intl.message(
      'Quick Access',
      name: 'quickAccess',
      desc: '',
      args: [],
    );
  }

  /// `Quran`
  String get quran_screen_title {
    return Intl.message(
      'Quran',
      name: 'quran_screen_title',
      desc: '',
      args: [],
    );
  }

  /// `Hadith`
  String get hadith_screen_title {
    return Intl.message(
      'Hadith',
      name: 'hadith_screen_title',
      desc: '',
      args: [],
    );
  }

  /// `Bookmarks`
  String get bookmarks_screen_title {
    return Intl.message(
      'Bookmarks',
      name: 'bookmarks_screen_title',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings_screen_title {
    return Intl.message(
      'Settings',
      name: 'settings_screen_title',
      desc: '',
      args: [],
    );
  }

  /// `All Surahs`
  String get all_surahs {
    return Intl.message(
      'All Surahs',
      name: 'all_surahs',
      desc: '',
      args: [],
    );
  }

  /// `{count} surahs`
  String surahs_count(Object count) {
    return Intl.message(
      '$count surahs',
      name: 'surahs_count',
      desc: '',
      args: [count],
    );
  }

  /// `Search for a surah...`
  String get search_surah_hint {
    return Intl.message(
      'Search for a surah...',
      name: 'search_surah_hint',
      desc: '',
      args: [],
    );
  }

  /// `The Noble Qur'an`
  String get the_noble_quran {
    return Intl.message(
      'The Noble Qur\'an',
      name: 'the_noble_quran',
      desc: '',
      args: [],
    );
  }

  /// `Surahs`
  String get surahs_appbar_title {
    return Intl.message(
      'Surahs',
      name: 'surahs_appbar_title',
      desc: '',
      args: [],
    );
  }

  /// `Collections`
  String get collections_label {
    return Intl.message(
      'Collections',
      name: 'collections_label',
      desc: '',
      args: [],
    );
  }

  /// `Hadith Books`
  String get hadith_books_appbar_title {
    return Intl.message(
      'Hadith Books',
      name: 'hadith_books_appbar_title',
      desc: '',
      args: [],
    );
  }

  /// `Books`
  String get books_section {
    return Intl.message(
      'Books',
      name: 'books_section',
      desc: '',
      args: [],
    );
  }

  /// `{count} books`
  String books_count(Object count) {
    return Intl.message(
      '$count books',
      name: 'books_count',
      desc: '',
      args: [count],
    );
  }

  /// `Ahadith`
  String get ahadith_section {
    return Intl.message(
      'Ahadith',
      name: 'ahadith_section',
      desc: '',
      args: [],
    );
  }

  /// `{count} ahadith`
  String ahadith_count(Object count) {
    return Intl.message(
      '$count ahadith',
      name: 'ahadith_count',
      desc: '',
      args: [count],
    );
  }

  /// `Narrator`
  String get narrator_label {
    return Intl.message(
      'Narrator',
      name: 'narrator_label',
      desc: '',
      args: [],
    );
  }

  /// `Next`
  String get next_hadith {
    return Intl.message(
      'Next',
      name: 'next_hadith',
      desc: '',
      args: [],
    );
  }

  /// `{percent}% complete`
  String progress_complete(Object percent) {
    return Intl.message(
      '$percent% complete',
      name: 'progress_complete',
      desc: '',
      args: [percent],
    );
  }

  /// `Makkiyya`
  String get makkiyya {
    return Intl.message(
      'Makkiyya',
      name: 'makkiyya',
      desc: '',
      args: [],
    );
  }

  /// `Madaniyya`
  String get madaniyya {
    return Intl.message(
      'Madaniyya',
      name: 'madaniyya',
      desc: '',
      args: [],
    );
  }

  /// `Appearance`
  String get appearance_section {
    return Intl.message(
      'Appearance',
      name: 'appearance_section',
      desc: '',
      args: [],
    );
  }

  /// `General`
  String get general_section {
    return Intl.message(
      'General',
      name: 'general_section',
      desc: '',
      args: [],
    );
  }

  /// `12h`
  String get time_format_12h {
    return Intl.message(
      '12h',
      name: 'time_format_12h',
      desc: '',
      args: [],
    );
  }

  /// `24h`
  String get time_format_24h {
    return Intl.message(
      '24h',
      name: 'time_format_24h',
      desc: '',
      args: [],
    );
  }

  /// `العربية`
  String get language_arabic {
    return Intl.message(
      'العربية',
      name: 'language_arabic',
      desc: '',
      args: [],
    );
  }

  /// `English`
  String get language_english {
    return Intl.message(
      'English',
      name: 'language_english',
      desc: '',
      args: [],
    );
  }

  /// `Search this book…`
  String get search_hadith_hint {
    return Intl.message(
      'Search this book…',
      name: 'search_hadith_hint',
      desc: '',
      args: [],
    );
  }

  /// `No matching ahadith`
  String get search_no_results {
    return Intl.message(
      'No matching ahadith',
      name: 'search_no_results',
      desc: '',
      args: [],
    );
  }

  /// `Filters`
  String get filters_title {
    return Intl.message(
      'Filters',
      name: 'filters_title',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get filter_status_label {
    return Intl.message(
      'Status',
      name: 'filter_status_label',
      desc: '',
      args: [],
    );
  }

  /// `Chapter`
  String get filter_chapter_label {
    return Intl.message(
      'Chapter',
      name: 'filter_chapter_label',
      desc: '',
      args: [],
    );
  }

  /// `All chapters`
  String get filter_all_chapters {
    return Intl.message(
      'All chapters',
      name: 'filter_all_chapters',
      desc: '',
      args: [],
    );
  }

  /// `Clear`
  String get filter_clear {
    return Intl.message(
      'Clear',
      name: 'filter_clear',
      desc: '',
      args: [],
    );
  }

  /// `Apply`
  String get filter_apply {
    return Intl.message(
      'Apply',
      name: 'filter_apply',
      desc: '',
      args: [],
    );
  }

  /// `Previous`
  String get previous_hadith {
    return Intl.message(
      'Previous',
      name: 'previous_hadith',
      desc: '',
      args: [],
    );
  }

  /// `Hadith of the Day`
  String get hadith_of_the_day {
    return Intl.message(
      'Hadith of the Day',
      name: 'hadith_of_the_day',
      desc: '',
      args: [],
    );
  }

  /// `Jumu'ah`
  String get jumuah {
    return Intl.message(
      'Jumu\'ah',
      name: 'jumuah',
      desc: '',
      args: [],
    );
  }

  /// `Adhan & Reminders`
  String get adhan_and_reminders {
    return Intl.message(
      'Adhan & Reminders',
      name: 'adhan_and_reminders',
      desc: '',
      args: [],
    );
  }

  /// `Quran`
  String get bookmarks_quran_section {
    return Intl.message(
      'Quran',
      name: 'bookmarks_quran_section',
      desc: '',
      args: [],
    );
  }

  /// `Ahadith`
  String get bookmarks_ahadith_section {
    return Intl.message(
      'Ahadith',
      name: 'bookmarks_ahadith_section',
      desc: '',
      args: [],
    );
  }

  /// `No bookmarks yet`
  String get no_bookmarks_yet {
    return Intl.message(
      'No bookmarks yet',
      name: 'no_bookmarks_yet',
      desc: '',
      args: [],
    );
  }

  /// `Test`
  String get test_section {
    return Intl.message(
      'Test',
      name: 'test_section',
      desc: '',
      args: [],
    );
  }

  /// `Al-Furqan`
  String get app_name {
    return Intl.message(
      'Al-Furqan',
      name: 'app_name',
      desc: '',
      args: [],
    );
  }

  /// `Continue`
  String get onb_continue {
    return Intl.message(
      'Continue',
      name: 'onb_continue',
      desc: '',
      args: [],
    );
  }

  /// `Enable`
  String get onb_enable {
    return Intl.message(
      'Enable',
      name: 'onb_enable',
      desc: '',
      args: [],
    );
  }

  /// `Not now`
  String get onb_not_now {
    return Intl.message(
      'Not now',
      name: 'onb_not_now',
      desc: '',
      args: [],
    );
  }

  /// `The Noble Qur'an, in your hands`
  String get onb_welcome_headline {
    return Intl.message(
      'The Noble Qur\'an, in your hands',
      name: 'onb_welcome_headline',
      desc: '',
      args: [],
    );
  }

  /// `Read, listen, and reflect — with your prayer times in one place.`
  String get onb_welcome_subtitle {
    return Intl.message(
      'Read, listen, and reflect — with your prayer times in one place.',
      name: 'onb_welcome_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Choose your language`
  String get onb_language_title {
    return Intl.message(
      'Choose your language',
      name: 'onb_language_title',
      desc: '',
      args: [],
    );
  }

  /// `You can change it later`
  String get onb_language_hint {
    return Intl.message(
      'You can change it later',
      name: 'onb_language_hint',
      desc: '',
      args: [],
    );
  }

  /// `Personalize your look`
  String get onb_appearance_title {
    return Intl.message(
      'Personalize your look',
      name: 'onb_appearance_title',
      desc: '',
      args: [],
    );
  }

  /// `Theme`
  String get onb_theme_label {
    return Intl.message(
      'Theme',
      name: 'onb_theme_label',
      desc: '',
      args: [],
    );
  }

  /// `Time format`
  String get onb_time_format_label {
    return Intl.message(
      'Time format',
      name: 'onb_time_format_label',
      desc: '',
      args: [],
    );
  }

  /// `Each time you open the app from now on`
  String get onb_splash_desc {
    return Intl.message(
      'Each time you open the app from now on',
      name: 'onb_splash_desc',
      desc: '',
      args: [],
    );
  }

  /// `Your prayer times, precisely`
  String get onb_location_title {
    return Intl.message(
      'Your prayer times, precisely',
      name: 'onb_location_title',
      desc: '',
      args: [],
    );
  }

  /// `We use your location to calculate accurate prayer times for your city. It stays on your device and is never shared.`
  String get onb_location_why {
    return Intl.message(
      'We use your location to calculate accurate prayer times for your city. It stays on your device and is never shared.',
      name: 'onb_location_why',
      desc: '',
      args: [],
    );
  }

  /// `Never miss a prayer`
  String get onb_notifications_title {
    return Intl.message(
      'Never miss a prayer',
      name: 'onb_notifications_title',
      desc: '',
      args: [],
    );
  }

  /// `Allow notifications to receive the adhan and prayer reminders on time. You can fine-tune them later in settings.`
  String get onb_notifications_why {
    return Intl.message(
      'Allow notifications to receive the adhan and prayer reminders on time. You can fine-tune them later in settings.',
      name: 'onb_notifications_why',
      desc: '',
      args: [],
    );
  }

  /// `Splash screen`
  String get show_splash_screen {
    return Intl.message(
      'Splash screen',
      name: 'show_splash_screen',
      desc: '',
      args: [],
    );
  }

  /// `Prayer times need your location`
  String get home_locationCard_title {
    return Intl.message(
      'Prayer times need your location',
      name: 'home_locationCard_title',
      desc: '',
      args: [],
    );
  }

  /// `We use it only to compute accurate prayer times.`
  String get home_locationCard_body {
    return Intl.message(
      'We use it only to compute accurate prayer times.',
      name: 'home_locationCard_body',
      desc: '',
      args: [],
    );
  }

  /// `Enable location`
  String get home_locationCard_enable {
    return Intl.message(
      'Enable location',
      name: 'home_locationCard_enable',
      desc: '',
      args: [],
    );
  }

  /// `Open settings`
  String get home_locationCard_openSettings {
    return Intl.message(
      'Open settings',
      name: 'home_locationCard_openSettings',
      desc: '',
      args: [],
    );
  }

  /// `Turn on notifications to hear the adhan`
  String get home_notifHint_text {
    return Intl.message(
      'Turn on notifications to hear the adhan',
      name: 'home_notifHint_text',
      desc: '',
      args: [],
    );
  }

  /// `Allow`
  String get home_notifHint_allow {
    return Intl.message(
      'Allow',
      name: 'home_notifHint_allow',
      desc: '',
      args: [],
    );
  }

  /// `Notifications are off — you won't hear the adhan.`
  String get notifSettings_disabledBanner_text {
    return Intl.message(
      'Notifications are off — you won\'t hear the adhan.',
      name: 'notifSettings_disabledBanner_text',
      desc: '',
      args: [],
    );
  }

  /// `Open settings`
  String get notifSettings_disabledBanner_action {
    return Intl.message(
      'Open settings',
      name: 'notifSettings_disabledBanner_action',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ar'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
