import 'package:flutter/material.dart';
import 'package:quran_app/config/router/app_router.dart';

void main() {
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quran',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      routerConfig: appRouter,
    );
  }
}
