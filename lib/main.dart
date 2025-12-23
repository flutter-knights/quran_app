import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/dark_theme.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init();
  await Hive.initFlutter();
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quran',
      theme: darkTheme,
      locale: Locale('ar'),
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: AppRouter.router,
    );
  }
}
