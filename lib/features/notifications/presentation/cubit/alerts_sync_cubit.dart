import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_cached_prayer_days.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
import 'package:quran_app/features/notifications/presentation/utils/strip_style_colors.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class AlertsSyncCubit extends Cubit<DateTime?> {
  AlertsSyncCubit({
    required this.settingsCubit,
    required this.getCachedPrayerDays,
    required this.syncDailyAdhans,
    required this.buildPrayerStripWindow,
    required this.enablePrayerStrip,
    required this.disablePrayerStrip,
    this.debounce = const Duration(milliseconds: 300),
    this.clock = DateTime.now,
  }) : super(null);

  final SettingsCubit settingsCubit;
  final GetCachedPrayerDays getCachedPrayerDays;
  final SyncDailyAdhans syncDailyAdhans;
  final BuildPrayerStripWindow buildPrayerStripWindow;
  final EnablePrayerStrip enablePrayerStrip;
  final DisablePrayerStrip disablePrayerStrip;
  final Duration debounce;
  final DateTime Function() clock;

  Timer? _timer;
  Future<void>? _running;
  bool _again = false;

  static bool listensTo(Settings prev, Settings curr) =>
      !mapEquals(prev.prayerAlerts, curr.prayerAlerts) ||
      prev.stripStyle != curr.stripStyle ||
      prev.isPrayerStripPinned != curr.isPrayerStripPinned ||
      prev.isArabic != curr.isArabic ||
      prev.isFormat12Hours != curr.isFormat12Hours ||
      prev.palette != curr.palette ||
      prev.calculationMethod != curr.calculationMethod ||
      prev.asrSchool != curr.asrSchool;

  void requestSync() {
    if (isClosed) return;
    _timer?.cancel();
    _timer = Timer(debounce, syncNow);
  }

  Future<void> syncNow() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _drain();
  }

  Future<void> _drain() async {
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again && !isClosed);
    } finally {
      _running = null;
    }
  }

  Future<void> _syncOnce() async {
    try {
      final s = settingsCubit.state.settingsModel;
      final now = clock();
      final localeCode = s.isArabic ? 'ar' : 'en';
      final days = await getCachedPrayerDays(
        GetCachedPrayerDaysParams(now: now),
      );
      if (!s.isPrayerStripPinned) {
        _logFailure('strip disable', await disablePrayerStrip(NoParams()));
      }
      if (days.isEmpty) return;
      _logFailure(
        'adhan sync',
        await syncDailyAdhans(
          SyncDailyAdhansParams(
            days: days,
            alerts: s.prayerAlerts,
            localeCode: localeCode,
          ),
        ),
      );
      if (s.isPrayerStripPinned) {
        final strings = PendingS.current;
        final window = await buildPrayerStripWindow(
          BuildPrayerStripWindowParams(
            localeCode: localeCode,
            use24Hour: s.is24HourFormat,
            now: now,
            days: 30,
            cachedDays: days,
            nextInLabel: strings.strip_nextIn,
            nextTag: strings.strip_next,
            style: stripRenderStyle(s.stripStyle, s.palette),
          ),
        );
        if (window != null) {
          _logFailure(
            'strip enable',
            await enablePrayerStrip(EnablePrayerStripParams(window: window)),
          );
        }
      }
      if (isClosed) return;
      emit(clock());
    } catch (e, st) {
      debugPrint('[alerts-sync] failed: $e\n$st');
    }
  }

  void _logFailure(String step, Either<Failure, Unit> result) => result.fold(
    (f) => debugPrint('[alerts-sync] $step failed: ${f.message}'),
    (_) {},
  );

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
