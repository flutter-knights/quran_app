import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_bottom_bar.dart';

// ---------------------------------------------------------------------------
// Fakes — a plain in-memory SettingsCubit avoids HydratedBloc.storage entirely
// (a real SettingsCubit's storage teardown hangs at full-suite scope).
// ---------------------------------------------------------------------------

class _FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettings()
      : super(const SettingsState(
            SettingsModel(isArabic: true, isFormat12Hours: false)));

  @override
  void updateMushafPaper(MushafPaper paper) {
    emit(SettingsState(state.settingsModel.copyWith(mushafPaper: paper)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf(super.initial);

  @override
  void clearHighlight() {}
  @override
  void toggleHighlight(AyahIdentifier a) {
    emit(state.copyWith(highlightedAyah: a));
  }

  @override
  void setPage(int p) {}
  @override
  void setHighlightBounds(double centerY) {}
  @override
  void pinOverlay() {}
  @override
  void unpinOverlay() {}
  @override
  void toggleChrome() {}
  @override
  void setChrome(bool visible) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier => throw UnimplementedError();
}

class _StubPageService implements QuranPageService {
  @override
  int getPageForAyah(int s, int a) => 1;
  @override
  AyahIdentifier? getFirstAyahOfPage(int p) => null;
}

void main() {
  final sl = GetIt.instance;

  setUp(() {
    if (sl.isRegistered<QuranPageService>()) sl.unregister<QuranPageService>();
    sl.registerSingleton<QuranPageService>(_StubPageService());
  });

  tearDown(() {
    if (sl.isRegistered<QuranPageService>()) sl.unregister<QuranPageService>();
  });

  testWidgets(
      'tapping the night swatch updates SettingsCubit to MushafPaper.night',
      (tester) async {
    final settingsCubit = _FakeSettings();
    final mushafCubit = _FakeMushaf(const MushafState(currentPage: 1));
    addTearDown(settingsCubit.close);
    addTearDown(mushafCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
              BlocProvider<MushafCubit>.value(value: mushafCubit),
            ],
            child: const MushafBottomBar(),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('mushaf-paper-night')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mushaf-paper-night')));
    await tester.pump();

    expect(settingsCubit.state.settingsModel.mushafPaper, MushafPaper.night);
  });
}
