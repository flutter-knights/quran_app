import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/refresh_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';

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
  sl.registerLazySingleton(
    () => BuildPrayerStripWindow(prayerTimesRepository: sl()),
  );
}
