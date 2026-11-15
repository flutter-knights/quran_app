import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/ack_missed_alerts.dart';
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_cached_prayer_days.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_reliability_status.dart';
import 'package:quran_app/features/notifications/domain/usecases/open_system_settings.dart';
import 'package:quran_app/features/notifications/domain/usecases/preview_alert_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/refresh_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/schedule_test_adhan.dart';
import 'package:quran_app/features/notifications/domain/usecases/stop_alert_preview.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
import 'package:quran_app/features/notifications/domain/usecases/watch_preview_ended.dart';
import 'package:quran_app/features/notifications/presentation/cubit/alerts_sync_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/sound_preview_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';

/// Registers Dart-side dependencies for the notifications feature.
/// The legacy `PrayerNotificationScheduler` must already be registered
/// (this happens in `initHome()`).
void initNotifications() {
  sl.registerLazySingleton<NotificationsNativeDataSource>(
    () => NotificationsNativeDataSourceImpl(),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(
      native: sl(),
      legacyScheduler: sl<PrayerNotificationScheduler>(),
    ),
  );
  sl.registerLazySingleton(() => EnablePrayerStrip(repository: sl()));
  sl.registerLazySingleton(() => DisablePrayerStrip(repository: sl()));
  sl.registerLazySingleton(() => RefreshPrayerStrip(repository: sl()));
  sl.registerLazySingleton(() => SyncDailyAdhans(repository: sl()));
  sl.registerLazySingleton(() => GetReliabilityStatus(repository: sl()));
  sl.registerLazySingleton(() => AckMissedAlerts(repository: sl()));
  sl.registerLazySingleton(() => OpenSystemSettings(repository: sl()));
  sl.registerLazySingleton(() => PreviewAlertSound(repository: sl()));
  sl.registerLazySingleton(() => StopAlertPreview(repository: sl()));
  sl.registerLazySingleton(() => ScheduleTestAdhan(repository: sl()));
  sl.registerLazySingleton(() => WatchPreviewEnded(repository: sl()));
  sl.registerLazySingleton(() => BuildPrayerStripWindow());
  sl.registerLazySingleton(
    () => GetCachedPrayerDays(prayerTimesRepository: sl()),
  );
  sl.registerFactory(
    () => AlertsSyncCubit(
      settingsCubit: sl(),
      getCachedPrayerDays: sl(),
      syncDailyAdhans: sl(),
      buildPrayerStripWindow: sl(),
      enablePrayerStrip: sl(),
      disablePrayerStrip: sl(),
    ),
  );
  sl.registerFactory(() => ReliabilityCubit(sl(), sl(), sl()));
  sl.registerFactory(() => SoundPreviewCubit(sl(), sl(), sl()));
  sl.registerFactory(() => TodayPrayerTimesCubit(sl()));
}
