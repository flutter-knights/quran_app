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
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name =
        (locale.countryCode?.isEmpty ?? false)
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
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Fajr`
  String get fajr {
    return Intl.message('Fajr', name: 'fajr', desc: '', args: []);
  }

  /// `Sunrise`
  String get sunrise {
    return Intl.message('Sunrise', name: 'sunrise', desc: '', args: []);
  }

  /// `Dhuhr`
  String get dhuhr {
    return Intl.message('Dhuhr', name: 'dhuhr', desc: '', args: []);
  }

  /// `Asr`
  String get asr {
    return Intl.message('Asr', name: 'asr', desc: '', args: []);
  }

  /// `Maghrib`
  String get maghrib {
    return Intl.message('Maghrib', name: 'maghrib', desc: '', args: []);
  }

  /// `Isha`
  String get isha {
    return Intl.message('Isha', name: 'isha', desc: '', args: []);
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
    Object weekday,
    Object day,
    Object month,
    Object year,
  ) {
    return Intl.message(
      '$weekday, $day $month $year AH',
      name: 'hijriDateWithDay',
      desc: '',
      args: [weekday, day, month, year],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Dark Mode`
  String get darkMode {
    return Intl.message('Dark Mode', name: 'darkMode', desc: '', args: []);
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
      "Show today's prayers in your notification shade.",
      name: 'pinnedPrayerTimesSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Notifications`
  String get notifications {
    return Intl.message('Notifications', name: 'notifications', desc: '', args: []);
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
    return Intl.message('Arabic', name: 'arabic_label', desc: '', args: []);
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
    return Intl.message('Chapter', name: 'chapter_label', desc: '', args: []);
  }

  /// `Sahih`
  String get status_sahih {
    return Intl.message('Sahih', name: 'status_sahih', desc: '', args: []);
  }

  /// `Hasan`
  String get status_hasan {
    return Intl.message('Hasan', name: 'status_hasan', desc: '', args: []);
  }

  /// `Da'eef`
  String get status_daeef {
    return Intl.message('Da\'eef', name: 'status_daeef', desc: '', args: []);
  }

  /// `Maudu'`
  String get status_mudu {
    return Intl.message('Maudu\'', name: 'status_mudu', desc: '', args: []);
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
    return Intl.message('256 AH', name: 'death_bukhari', desc: '', args: []);
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
    return Intl.message('261 AH', name: 'death_muslim', desc: '', args: []);
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
    return Intl.message('279 AH', name: 'death_tirmidhi', desc: '', args: []);
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
    return Intl.message('275 AH', name: 'death_abu_dawood', desc: '', args: []);
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
    return Intl.message('273 AH', name: 'death_ibn_majah', desc: '', args: []);
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
    return Intl.message('303 AH', name: 'death_nasai', desc: '', args: []);
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
    return Intl.message('741 AH', name: 'death_mishkat', desc: '', args: []);
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
    return Intl.message('241 AH', name: 'death_ahmad', desc: '', args: []);
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

  /// `Imam Muhammad Nasiruddin al-Albani`
  String get author_albani {
    return Intl.message(
      'Imam Muhammad Nasiruddin al-Albani',
      name: 'author_albani',
      desc: '',
      args: [],
    );
  }

  /// `1420 AH`
  String get death_albani {
    return Intl.message('1420 AH', name: 'death_albani', desc: '', args: []);
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
    return Intl.message('Tafsir', name: 'tafsir', desc: '', args: []);
  }

  /// `Translation`
  String get translation {
    return Intl.message('Translation', name: 'translation', desc: '', args: []);
  }

  /// `Play`
  String get play {
    return Intl.message('Play', name: 'play', desc: '', args: []);
  }

  /// `Bookmark`
  String get bookmark {
    return Intl.message('Bookmark', name: 'bookmark', desc: '', args: []);
  }

  /// `Share`
  String get share {
    return Intl.message('Share', name: 'share', desc: '', args: []);
  }

  /// `Coming soon`
  String get coming_soon {
    return Intl.message('Coming soon', name: 'coming_soon', desc: '', args: []);
  }

  /// `Bookmarked`
  String get bookmark_added {
    return Intl.message('Bookmarked', name: 'bookmark_added', desc: '', args: []);
  }

  /// `Bookmark removed`
  String get bookmark_removed {
    return Intl.message('Bookmark removed', name: 'bookmark_removed', desc: '', args: []);
  }

  /// `Couldn't save bookmark`
  String get bookmark_save_failed {
    return Intl.message("Couldn't save bookmark", name: 'bookmark_save_failed', desc: '', args: []);
  }

  /// `Couldn't open share sheet`
  String get share_failed {
    return Intl.message("Couldn't open share sheet", name: 'share_failed', desc: '', args: []);
  }

  /// `Pause`
  String get playback_pause {
    return Intl.message('Pause', name: 'playback_pause', desc: '', args: []);
  }

  /// `Next ayah`
  String get playback_next {
    return Intl.message('Next ayah', name: 'playback_next', desc: '', args: []);
  }

  /// `Previous ayah`
  String get playback_previous {
    return Intl.message('Previous ayah', name: 'playback_previous', desc: '', args: []);
  }

  /// `Restart`
  String get playback_restart {
    return Intl.message('Restart', name: 'playback_restart', desc: '', args: []);
  }

  /// `Close`
  String get playback_close {
    return Intl.message('Close', name: 'playback_close', desc: '', args: []);
  }

  /// `Speed`
  String get playback_speed {
    return Intl.message('Speed', name: 'playback_speed', desc: '', args: []);
  }

  /// `Reciter`
  String get reciter_label {
    return Intl.message('Reciter', name: 'reciter_label', desc: '', args: []);
  }

  /// `Continue reading`
  String get continue_reading {
    return Intl.message('Continue reading', name: 'continue_reading', desc: '', args: []);
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
    return Intl.message('Play surah', name: 'play_surah', desc: '', args: []);
  }

  /// `Adhan per prayer`
  String get adhanPerPrayerSection {
    return Intl.message('Adhan per prayer', name: 'adhanPerPrayerSection', desc: '', args: []);
  }

  /// `Remind me`
  String get reminderLabel {
    return Intl.message('Remind me', name: 'reminderLabel', desc: '', args: []);
  }

  /// `Off`
  String get reminderOff {
    return Intl.message('Off', name: 'reminderOff', desc: '', args: []);
  }

  /// `{minutes} min before`
  String reminderMinutesBefore(Object minutes) {
    return Intl.message(
      '$minutes min before',
      name: 'reminderMinutesBefore',
      desc: '',
      args: [minutes],
    );
  }

  /// `Play test adhan`
  String get playTestAdhan {
    return Intl.message('Play test adhan', name: 'playTestAdhan', desc: '', args: []);
  }

  /// `Test adhan in 5 seconds`
  String get testAdhanScheduledSnack {
    return Intl.message('Test adhan in 5 seconds', name: 'testAdhanScheduledSnack', desc: '', args: []);
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
