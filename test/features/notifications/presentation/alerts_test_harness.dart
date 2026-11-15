import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class MemStorage implements Storage {
  final _m = <String, dynamic>{};
  @override
  dynamic read(String key) => _m[key];
  @override
  Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
  @override
  Future<void> close() async {}
}

const _delegates = <LocalizationsDelegate<dynamic>>[
  S.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget alertsApp({
  required SettingsCubit settings,
  required Widget home,
  String locale = 'ar',
}) {
  return BlocProvider.value(
    value: settings,
    child: MaterialApp(
      locale: Locale(locale),
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: _delegates,
      theme: settings.state.settingsModel.palette.toThemeData(),
      home: home,
    ),
  );
}

Widget alertsRouterApp({
  required SettingsCubit settings,
  required GoRouter router,
  String locale = 'ar',
}) {
  return BlocProvider.value(
    value: settings,
    child: MaterialApp.router(
      locale: Locale(locale),
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: _delegates,
      theme: settings.state.settingsModel.palette.toThemeData(),
      routerConfig: router,
    ),
  );
}

PrayerTimes cairoToday() => PrayerTimes(
  key: '15-11-2026',
  timings: const {
    PrayerName.fajr: '04:50',
    PrayerName.sunrise: '06:18',
    PrayerName.dhuhr: '11:39',
    PrayerName.asr: '14:38',
    PrayerName.maghrib: '16:59',
    PrayerName.isha: '18:19',
  },
  date: Date(
    month: 'جمادى الآخرة',
    weekDay: 'الأحد',
    day: '5',
    year: '1448',
    enMonth: 'Jumada al-Akhirah',
    enWeekDay: 'Sunday',
    gregorianDate: '15-11-2026',
  ),
);

Future<void> loadAppFonts() async {
  const weights = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  for (final family in ['Cairo', 'Roboto']) {
    final loader = FontLoader(family);
    for (final w in weights) {
      final bytes = File('assets/fonts/Cairo-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}
