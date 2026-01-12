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

  /// `Sahih`
  String get status_sahih {
    return Intl.message('Sahih', name: 'status_sahih', desc: '', args: []);
  }

  /// `Hasan`
  String get status_hasan {
    return Intl.message('Hasan', name: 'status_hasan', desc: '', args: []);
  }

  /// `Daeef`
  String get status_daeef {
    return Intl.message('Daeef', name: 'status_daeef', desc: '', args: []);
  }

  /// `Maudu`
  String get status_mudu {
    return Intl.message('Maudu', name: 'status_mudu', desc: '', args: []);
  }

  /// `Sahih Bukhari`
  String get sahih_bukhari {
    return Intl.message(
      'Sahih Bukhari',
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

  /// `Jami' Al-Tirmidhi`
  String get al_tirmidhi {
    return Intl.message(
      'Jami\' Al-Tirmidhi',
      name: 'al_tirmidhi',
      desc: '',
      args: [],
    );
  }

  /// `Sunan Abu Dawood`
  String get abu_dawood {
    return Intl.message(
      'Sunan Abu Dawood',
      name: 'abu_dawood',
      desc: '',
      args: [],
    );
  }

  /// `Sunan Ibn-e-Majah`
  String get ibn_e_majah {
    return Intl.message(
      'Sunan Ibn-e-Majah',
      name: 'ibn_e_majah',
      desc: '',
      args: [],
    );
  }

  /// `Sunan An-Nasa'i`
  String get sunan_nasai {
    return Intl.message(
      'Sunan An-Nasa\'i',
      name: 'sunan_nasai',
      desc: '',
      args: [],
    );
  }

  /// `Mishkat Al-Masabih`
  String get mishkat {
    return Intl.message(
      'Mishkat Al-Masabih',
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

  /// `Al-Silsila Sahiha`
  String get al_silsila_sahiha {
    return Intl.message(
      'Al-Silsila Sahiha',
      name: 'al_silsila_sahiha',
      desc: '',
      args: [],
    );
  }

  /// `Muhammad ibn Isma'il al-Bukhari`
  String get author_bukhari {
    return Intl.message(
      'Muhammad ibn Isma\'il al-Bukhari',
      name: 'author_bukhari',
      desc: '',
      args: [],
    );
  }

  /// `256 AH`
  String get death_bukhari {
    return Intl.message('256 AH', name: 'death_bukhari', desc: '', args: []);
  }

  /// `The Abridged Collection of Authentic Hadith`
  String get full_title_bukhari {
    return Intl.message(
      'The Abridged Collection of Authentic Hadith',
      name: 'full_title_bukhari',
      desc: '',
      args: [],
    );
  }

  /// `Muslim ibn al-Hajjaj al-Naysaburi`
  String get author_muslim {
    return Intl.message(
      'Muslim ibn al-Hajjaj al-Naysaburi',
      name: 'author_muslim',
      desc: '',
      args: [],
    );
  }

  /// `261 AH`
  String get death_muslim {
    return Intl.message('261 AH', name: 'death_muslim', desc: '', args: []);
  }

  /// `The Abbreviated Authentic Musnad`
  String get full_title_muslim {
    return Intl.message(
      'The Abbreviated Authentic Musnad',
      name: 'full_title_muslim',
      desc: '',
      args: [],
    );
  }

  /// `Muhammad ibn 'Isa al-Tirmidhi`
  String get author_tirmidhi {
    return Intl.message(
      'Muhammad ibn \'Isa al-Tirmidhi',
      name: 'author_tirmidhi',
      desc: '',
      args: [],
    );
  }

  /// `279 AH`
  String get death_tirmidhi {
    return Intl.message('279 AH', name: 'death_tirmidhi', desc: '', args: []);
  }

  /// `Jami' at-Tirmidhi`
  String get full_title_tirmidhi {
    return Intl.message(
      'Jami\' at-Tirmidhi',
      name: 'full_title_tirmidhi',
      desc: '',
      args: [],
    );
  }

  /// `Abu Dawood al-Sijistani`
  String get author_abu_dawood {
    return Intl.message(
      'Abu Dawood al-Sijistani',
      name: 'author_abu_dawood',
      desc: '',
      args: [],
    );
  }

  /// `275 AH`
  String get death_abu_dawood {
    return Intl.message('275 AH', name: 'death_abu_dawood', desc: '', args: []);
  }

  /// `Sunan Abi Dawud`
  String get full_title_abu_dawood {
    return Intl.message(
      'Sunan Abi Dawud',
      name: 'full_title_abu_dawood',
      desc: '',
      args: [],
    );
  }

  /// `Ibn Majah al-Qazwini`
  String get author_ibn_majah {
    return Intl.message(
      'Ibn Majah al-Qazwini',
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

  /// `Ahmad ibn Shu'ayb al-Nasa'i`
  String get author_nasai {
    return Intl.message(
      'Ahmad ibn Shu\'ayb al-Nasa\'i',
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

  /// `Al-Khatib al-Tabrizi`
  String get author_mishkat {
    return Intl.message(
      'Al-Khatib al-Tabrizi',
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

  /// `Ahmad ibn Hanbal`
  String get author_ahmad {
    return Intl.message(
      'Ahmad ibn Hanbal',
      name: 'author_ahmad',
      desc: '',
      args: [],
    );
  }

  /// `241 AH`
  String get death_ahmad {
    return Intl.message('241 AH', name: 'death_ahmad', desc: '', args: []);
  }

  /// `Musnad Ahmad ibn Hanbal`
  String get full_title_ahmad {
    return Intl.message(
      'Musnad Ahmad ibn Hanbal',
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
