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
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_skeleton.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_fallback_card.dart';
import 'package:quran_app/generated/l10n.dart';

class _MockQiblaCubit extends MockCubit<QiblaState> implements QiblaCubit {}

void main() {
  late _MockQiblaCubit cubit;
  setUp(() => cubit = _MockQiblaCubit());

  Widget host() => MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: BlocProvider<QiblaCubit>.value(
            value: cubit, child: const QiblaPage()),
      );

  testWidgets('shows skeleton while loading', (tester) async {
    when(() => cubit.state).thenReturn(const QiblaLoading());
    await tester.pumpWidget(host());
    expect(find.byType(QiblaSkeleton), findsOneWidget);
  });

  testWidgets('shows fallback card when hasCompass is false', (tester) async {
    when(() => cubit.state).thenReturn(const QiblaLoaded(
      direction: QiblaDirection(
          bearing: 136, distanceKm: 1287, rose: CompassRose.se),
      locationName: 'Cairo',
      hasCompass: false,
    ));
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(QiblaFallbackCard), findsOneWidget);
  });
}
