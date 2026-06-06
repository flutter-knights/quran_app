import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/hive_config.dart';
import 'package:quran_app/config/hydrated_bloc_config.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  // Unlock all orientations so the device's auto-rotate setting is respected
  // and the Mushaf can switch to landscape scroll mode on rotation.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const AppLoader());
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await initHydratedCubit();
    await initHive();
    await initGetIt();
    if (!mounted) return;
    setState(() => _ready = true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      while (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      try {
        await sl<PrayerNotificationScheduler>().init();
      } catch (e, st) {
        debugPrint('PrayerNotificationScheduler.init failed: $e\n$st');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFF0D0D0D)),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SettingsCubit>()),
        BlocProvider(create: (_) => sl<BookmarkCubit>()),
        BlocProvider(create: (_) => sl<LastReadCubit>()),
        BlocProvider(create: (_) => sl<PlaybackCubit>()),
        BlocProvider(create: (_) => sl<DownloadBookCubit>()),
      ],
      child: const QuranApp(),
    );
  }
}

class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Read the already-hydrated settings once to pick the entry route, then
    // build the router a single time (kept out of the BlocBuilder below so
    // navigation state survives theme/locale changes). First run → splash
    // (which hands off to the landing); later runs → splash if enabled,
    // otherwise straight to home.
    final settings = context.read<SettingsCubit>().state.settingsModel;
    final initialLocation =
        settings.hasCompletedOnboarding && !settings.showSplashOnLaunch
        ? AppRouter.homePath
        : AppRouter.splashPath;
    _router = AppRouter.createRouter(initialLocation: initialLocation);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = state.settingsModel;
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Quran',
          theme: settings.palette.toThemeData(),
          locale: settings.isArabic ? const Locale('ar') : const Locale('en'),
          supportedLocales: S.delegate.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        );
      },
    );
  }
}
