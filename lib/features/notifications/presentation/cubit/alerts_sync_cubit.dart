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
  bool _timerFull = false;
  Future<void>? _running;
  bool? _queued;

  static bool needsSync(Settings prev, Settings curr) =>
      !mapEquals(prev.prayerAlerts, curr.prayerAlerts) ||
      prev.isArabic != curr.isArabic ||
      prev.calculationMethod != curr.calculationMethod ||
      prev.asrSchool != curr.asrSchool;

  static bool needsStripRefresh(Settings prev, Settings curr) =>
      prev.stripStyle != curr.stripStyle ||
      prev.isPrayerStripPinned != curr.isPrayerStripPinned ||
      prev.isFormat12Hours != curr.isFormat12Hours ||
      prev.palette != curr.palette;

  void requestSync() => _request(full: true);

  void requestStripRefresh() => _request(full: false);

  void _request({required bool full}) {
    if (isClosed) return;
    _timer?.cancel();
    _timerFull |= full;
    _timer = Timer(debounce, () {
      final pending = _timerFull;
      _timerFull = false;
      _start(full: pending);
    });
  }

  Future<void> syncNow() => _start(full: true);

  Future<void> refreshStripNow() => _start(full: false);

  Future<void> _start({required bool full}) {
    final running = _running;
    if (running != null) {
      _queued = full || (_queued ?? false);
      return running;
    }
    return _running = _drain(full);
  }

  Future<void> _drain(bool full) async {
    try {
      bool? next = full;
      while (next != null && !isClosed) {
        _queued = null;
        await _pass(full: next);
        next = _queued;
      }
    } finally {
      _queued = null;
      _running = null;
    }
  }

  Future<void> _pass({required bool full}) async {
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
      if (full) {
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
      }
      if (s.isPrayerStripPinned) {
        final strings = PendingS.forLanguage(localeCode);
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
      if (!full || isClosed) return;
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
