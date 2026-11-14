import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/domain/entities/qibla_direction.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:quran_app/features/qibla/presentation/pages/qibla_page.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart';
import 'package:quran_app/generated/l10n.dart';

class _MockQiblaCubit extends MockCubit<QiblaState> implements QiblaCubit {}

/// Covers the full QiblaLoaded(hasCompass: true) compass view — the live needle,
/// status pill, degree readout and meta cards rendering together — under the
/// Arabic locale. (The original page test only exercised the skeleton and the
/// no-compass fallback.)
void main() {
  testWidgets('renders the live compass view without overflow (Arabic locale)',
      (tester) async {
    final cubit = _MockQiblaCubit();
    when(() => cubit.state).thenReturn(const QiblaLoaded(
      direction:
          QiblaDirection(bearing: 136, distanceKm: 1287, rose: CompassRose.se),
      locationName: 'القاهرة, مصر',
      hasCompass: true,
      trueHeading: 100,
      accuracy: 5,
    ));

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ar'),
      supportedLocales: S.delegate.supportedLocales,
      home:
          BlocProvider<QiblaCubit>.value(value: cubit, child: const QiblaPage()),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(QiblaCompassDial), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
