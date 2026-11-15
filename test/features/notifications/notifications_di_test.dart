import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_android_sdk_int.dart';
import 'package:quran_app/features/notifications/domain/usecases/watch_preview_ended.dart';
import 'package:quran_app/features/notifications/notifications_di.dart';
import 'package:quran_app/features/notifications/presentation/cubit/android_sdk_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/sound_preview_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';

class _MockScheduler extends Mock implements PrayerNotificationScheduler {}

class _MockPrayerTimesRepository extends Mock
    implements PrayerTimesRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => sl.reset());

  test('initNotifications resolves the alerts cubits and use cases', () async {
    sl.registerLazySingleton<PrayerNotificationScheduler>(
      () => _MockScheduler(),
    );
    sl.registerLazySingleton<PrayerTimesRepository>(
      () => _MockPrayerTimesRepository(),
    );
    initNotifications();

    expect(sl<WatchPreviewEnded>(), isA<WatchPreviewEnded>());
    expect(sl<GetAndroidSdkInt>(), isA<GetAndroidSdkInt>());
    final reliability = sl<ReliabilityCubit>();
    final preview = sl<SoundPreviewCubit>();
    final today = sl<TodayPrayerTimesCubit>();
    final another = sl<SoundPreviewCubit>();
    final sdk = sl<AndroidSdkCubit>();
    expect(identical(preview, another), isFalse);

    for (final cubit in [reliability, preview, another, today, sdk]) {
      await cubit.close();
    }
  });
}
