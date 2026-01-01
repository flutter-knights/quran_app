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
