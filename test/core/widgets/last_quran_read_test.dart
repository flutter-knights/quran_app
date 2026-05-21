import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/widgets/last_quran_read.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeCubit extends Cubit<LastRead?> implements LastReadCubit {
  _FakeCubit(super.initial);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(_FakeCubit cubit, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    locale: locale,
    home: Scaffold(
      body: BlocProvider<LastReadCubit>.value(
        value: cubit,
        child: const LastQuranRead(),
      ),
    ),
  );
}

void main() {
  testWidgets('renders ayah label when ayah present', (tester) async {
    final cubit = _FakeCubit(
        const LastRead(page: 42, ayah: AyahIdentifier(surah: 2, ayah: 5)));
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Surah 2, Ayah 5'), findsOneWidget);
  });

  testWidgets('renders page label when no ayah', (tester) async {
    final cubit = _FakeCubit(const LastRead(page: 42));
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page 42'), findsOneWidget);
  });

  testWidgets('renders Continue label', (tester) async {
    final cubit = _FakeCubit(const LastRead(page: 1));
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Continue reading'), findsWidgets);
  });
}
