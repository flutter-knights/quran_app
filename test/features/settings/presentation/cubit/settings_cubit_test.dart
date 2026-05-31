import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

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

  test('updatePageBrightness clamps to [0.3, 1.0]', () {
    final c = SettingsCubit();
    c.updatePageBrightness(0.1);
    expect(c.state.settingsModel.pageBrightness, 0.3);
    c.updatePageBrightness(0.7);
    expect(c.state.settingsModel.pageBrightness, 0.7);
  });

  test('updateReadingMode switches mode', () {
    final c = SettingsCubit();
    c.updateReadingMode(MushafReadingMode.scroll);
    expect(c.state.settingsModel.readingMode, MushafReadingMode.scroll);
  });
}
