import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_cached_prayer_days.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
import 'package:quran_app/features/notifications/presentation/cubit/alerts_sync_cubit.dart';
import 'package:quran_app/features/notifications/presentation/utils/strip_style_colors.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class _MemStorage implements Storage {
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

class _MockGetDays extends Mock implements GetCachedPrayerDays {}

class _MockSync extends Mock implements SyncDailyAdhans {}

class _MockBuild extends Mock implements BuildPrayerStripWindow {}

class _MockEnable extends Mock implements EnablePrayerStrip {}

class _MockDisable extends Mock implements DisablePrayerStrip {}

PrayerTimes fakePrayerTimes(DateTime d) {
  final key =
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  return PrayerTimes(
    key: key,
    timings: const {
      PrayerName.fajr: '04:15',
      PrayerName.sunrise: '05:07',
      PrayerName.dhuhr: '12:52',
      PrayerName.asr: '16:28',
      PrayerName.maghrib: '19:46',
      PrayerName.isha: '21:16',
    },
    date: Date(
      month: 'جمادى الأولى',
      weekDay: 'الأحد',
      day: '1',
      year: '1448',
      enMonth: 'Jumada al-Ula',
      enWeekDay: 'Sunday',
      gregorianDate: key,
    ),
  );
}

void main() {
  final now = DateTime(2026, 11, 15, 9);
  final cachedDays = [
    for (var i = 0; i < 30; i++) fakePrayerTimes(DateTime(2026, 11, 15 + i)),
  ];
  const window = PrayerStripWindow(days: []);

  late SettingsCubit settingsCubit;
  late _MockGetDays getDays;
  late _MockSync sync;
  late _MockBuild build;
  late _MockEnable enable;
  late _MockDisable disable;
  late AlertsSyncCubit cubit;

  setUpAll(() {
    HydratedBloc.storage = _MemStorage();
    registerFallbackValue(GetCachedPrayerDaysParams());
    registerFallbackValue(
      const SyncDailyAdhansParams(days: [], alerts: {}, localeCode: 'ar'),
    );
    registerFallbackValue(
      const BuildPrayerStripWindowParams(
        localeCode: 'ar',
        use24Hour: true,
        cachedDays: [],
      ),
    );
    registerFallbackValue(const EnablePrayerStripParams(window: window));
    registerFallbackValue(NoParams());
  });

  setUp(() async {
    await HydratedBloc.storage.clear();
    settingsCubit = SettingsCubit();
    getDays = _MockGetDays();
    sync = _MockSync();
    build = _MockBuild();
    enable = _MockEnable();
    disable = _MockDisable();
    when(() => getDays(any())).thenAnswer((_) async => cachedDays);
    when(() => sync(any())).thenAnswer((_) async => const Right(unit));
    when(() => build(any())).thenAnswer((_) async => window);
    when(() => enable(any())).thenAnswer((_) async => const Right(unit));
    when(() => disable(any())).thenAnswer((_) async => const Right(unit));
    cubit = AlertsSyncCubit(
      settingsCubit: settingsCubit,
      getCachedPrayerDays: getDays,
      syncDailyAdhans: sync,
      buildPrayerStripWindow: build,
      enablePrayerStrip: enable,
      disablePrayerStrip: disable,
      debounce: const Duration(milliseconds: 20),
      clock: () => now,
    );
  });

  tearDown(() async {
    await cubit.close();
    await settingsCubit.close();
  });

  group('AlertsSyncCubit', () {
    test('debounces bursts into one sync', () async {
      cubit.requestSync();
      cubit.requestSync();
      cubit.requestSync();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      verifyNever(() => sync(any()));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      verify(() => sync(any())).called(1);
    });

    test('close during debounce cancels the pending sync', () async {
      cubit.requestSync();
      await cubit.close();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      verifyNever(() => sync(any()));
    });

    test('sends every cached day and the settings alerts', () async {
      await cubit.syncNow();
      final p =
          verify(() => sync(captureAny())).captured.single
              as SyncDailyAdhansParams;
      expect(p.days.length, 30);
      expect(p.alerts, settingsCubit.state.settingsModel.prayerAlerts);
      expect(p.localeCode, 'ar');
      final daysParams =
          verify(() => getDays(captureAny())).captured.single
              as GetCachedPrayerDaysParams;
      expect(daysParams.now, now);
      expect(daysParams.maxDays, 30);
    });

    test('emits the sync time after a completed sync', () async {
      await cubit.syncNow();
      expect(cubit.state, now);
    });

    test('strip pinned builds a 30-day window and enables it', () async {
      settingsCubit
        ..updatePrayerStripPinned(true)
        ..updatePalette(ColorPalette.neutralDark);
      await cubit.syncNow();
      final p =
          verify(() => build(captureAny())).captured.single
              as BuildPrayerStripWindowParams;
      expect(p.days, 30);
      expect(p.now, now);
      expect(p.localeCode, 'ar');
      expect(p.use24Hour, settingsCubit.state.settingsModel.is24HourFormat);
      final e =
          verify(() => enable(captureAny())).captured.single
              as EnablePrayerStripParams;
      expect(e.window, same(window));
      verifyNever(() => disable(any()));
    });

    test('strip labels follow the app language, not Intl', () async {
      final previous = Intl.defaultLocale;
      Intl.defaultLocale = 'en';
      addTearDown(() => Intl.defaultLocale = previous);
      settingsCubit
        ..updatePrayerStripPinned(true)
        ..updatePalette(ColorPalette.slateLight)
        ..updateStripStyle(
          const StripStyle(
            highlight: StripHighlight.indigo,
            shape: StripShape.pill,
          ),
        );
      await cubit.syncNow();
      final s = settingsCubit.state.settingsModel;
      final p =
          verify(() => build(captureAny())).captured.single
              as BuildPrayerStripWindowParams;
      expect(p.style, stripRenderStyle(s.stripStyle, s.palette));
      expect(p.style!.highlightDay, 0xFF4B4FA6);
      expect(p.nextTag, 'التالية');
      expect(p.nextInLabel!('العصر'), 'العصر بعد');
    });

    test('English app language gives English strip labels', () async {
      final previous = Intl.defaultLocale;
      Intl.defaultLocale = 'ar';
      addTearDown(() => Intl.defaultLocale = previous);
      settingsCubit
        ..updatePrayerStripPinned(true)
        ..updateSettings(isArabic: false);
      await cubit.syncNow();
      final p =
          verify(() => build(captureAny())).captured.single
              as BuildPrayerStripWindowParams;
      expect(p.localeCode, 'en');
      expect(p.nextTag, 'Next');
      expect(p.nextInLabel!('Asr'), 'Asr in');
    });

    test('strip pinned with no window skips enable', () async {
      settingsCubit.updatePrayerStripPinned(true);
      when(() => build(any())).thenAnswer((_) async => null);
      await cubit.syncNow();
      verifyNever(() => enable(any()));
      verifyNever(() => disable(any()));
    });

    test('strip unpinned disables it', () async {
      await cubit.syncNow();
      verify(() => disable(any())).called(1);
      verifyNever(() => enable(any()));
      verifyNever(() => build(any()));
    });

    test('no cached days skips the sync call', () async {
      when(() => getDays(any())).thenAnswer((_) async => []);
      await cubit.syncNow();
      verifyNever(() => sync(any()));
      verifyNever(() => build(any()));
      expect(cubit.state, isNull);
    });

    test('no cached days still hides an unpinned strip', () async {
      when(() => getDays(any())).thenAnswer((_) async => []);
      await cubit.syncNow();
      verify(() => disable(any())).called(1);
    });

    test('strip reuses the days already read', () async {
      settingsCubit.updatePrayerStripPinned(true);
      await cubit.syncNow();
      final p =
          verify(() => build(captureAny())).captured.single
              as BuildPrayerStripWindowParams;
      expect(p.cachedDays, same(cachedDays));
      verify(() => getDays(any())).called(1);
    });

    test('a failed adhan sync still updates the strip', () async {
      when(
        () => sync(any()),
      ).thenAnswer((_) async => const Left(UnknownFailure('boom')));
      await cubit.syncNow();
      verify(() => disable(any())).called(1);
      expect(cubit.state, now);
    });

    test('a throwing use case never escapes syncNow', () async {
      when(() => getDays(any())).thenThrow(Exception('hive'));
      await expectLater(cubit.syncNow(), completes);
    });

    test('a sync that finishes after close does not emit', () async {
      when(() => sync(any())).thenAnswer((_) async {
        await cubit.close();
        return const Right(unit);
      });
      await expectLater(cubit.syncNow(), completes);
      expect(cubit.state, isNull);
    });

    test(
      'a sync requested mid-pass runs once more with fresh settings',
      () async {
        settingsCubit.updatePrayerStripPinned(true);
        final held = Completer<Either<Failure, Unit>>();
        when(() => enable(any())).thenAnswer((_) => held.future);
        final first = cubit.syncNow();
        await Future<void>.delayed(Duration.zero);
        settingsCubit.updatePrayerStripPinned(false);
        final second = cubit.syncNow();
        final third = cubit.syncNow();
        expect(second, same(first));
        expect(third, same(first));
        held.complete(const Right(unit));
        await first;
        verify(() => getDays(any())).called(2);
        verifyInOrder([() => enable(any()), () => disable(any())]);
        verifyNever(() => enable(any()));
        verifyNoMoreInteractions(disable);
      },
    );

    test('a close mid-pass skips the queued pass', () async {
      final held = Completer<Either<Failure, Unit>>();
      when(() => sync(any())).thenAnswer((_) => held.future);
      final first = cubit.syncNow();
      await Future<void>.delayed(Duration.zero);
      cubit.syncNow();
      await cubit.close();
      held.complete(const Right(unit));
      await first;
      verify(() => getDays(any())).called(1);
    });

    test('a new sync starts after the previous one finished', () async {
      await cubit.syncNow();
      await cubit.syncNow();
      verify(() => getDays(any())).called(2);
    });

    test('listensTo ignores unrelated fields', () {
      final s = settingsCubit.state.settingsModel;
      expect(
        AlertsSyncCubit.listensTo(s, s.copyWith(pageBrightness: 0.5)),
        isFalse,
      );
      expect(
        AlertsSyncCubit.listensTo(
          s,
          s.copyWith(stripStyle: const StripStyle(expanded: false)),
        ),
        isTrue,
      );
    });

    test('listensTo reacts to every scheduling field', () {
      final s = settingsCubit.state.settingsModel;
      final changed = [
        s.copyWith(
          prayerAlerts: {
            ...s.prayerAlerts,
            PrayerName.fajr: const PrayerAlert(enabled: false),
          },
        ),
        s.copyWith(isPrayerStripPinned: !s.isPrayerStripPinned),
        s.copyWith(isArabic: !s.isArabic),
        s.copyWith(isFormat12Hours: !s.isFormat12Hours),
        s.copyWith(palette: ColorPalette.values.last),
        s.copyWith(calculationMethod: CalculationMethod.values.last),
        s.copyWith(asrSchool: AsrSchool.hanafi),
      ];
      for (final c in changed) {
        expect(AlertsSyncCubit.listensTo(s, c), isTrue);
      }
    });

    test('listensTo treats an equal alerts map as unchanged', () {
      final s = settingsCubit.state.settingsModel;
      expect(
        AlertsSyncCubit.listensTo(
          s,
          s.copyWith(prayerAlerts: Map.of(s.prayerAlerts)),
        ),
        isFalse,
      );
    });
  });
}
