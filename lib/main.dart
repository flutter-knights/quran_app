import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/hive_config.dart';
import 'package:quran_app/config/hydrated_bloc_config.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/dark_theme.dart';
import 'package:quran_app/config/theme/light_theme.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  WidgetsFlutterBinding.ensureInitialized();
  await initHydratedCubit();
  await initHive();
  await initGetIt();

  runApp(
    MultiBlocProvider(
      providers: [BlocProvider(create: (_) => sl<SettingsCubit>())],
      child: const QuranApp(),
    ),
  );
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = state.settingsModel;

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Quran',
          theme: settings.isDarkMode ? darkTheme : lightTheme,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: settings.isArabic ? const Locale('ar') : const Locale('en'),
          supportedLocales: S.delegate.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
