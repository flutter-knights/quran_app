import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart';
import 'package:quran_app/generated/l10n.dart';

class _MemStorage implements Storage {
  final _m = <String, dynamic>{};
  @override dynamic read(String key) => _m[key];
  @override Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override Future<void> delete(String key) async => _m.remove(key);
  @override Future<void> clear() async => _m.clear();
  @override Future<void> close() async {}
}

void main() {
  setUpAll(() => HydratedBloc.storage = _MemStorage());

  testWidgets('tapping the night swatch updates the paper setting',
      (tester) async {
    final cubit = SettingsCubit();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: ReadingSettingsSheet()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reading-paper-night')));
    await tester.pump();
    expect(cubit.state.settingsModel.mushafPaper, MushafPaper.night);
  });
}
