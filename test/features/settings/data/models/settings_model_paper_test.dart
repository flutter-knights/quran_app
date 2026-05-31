import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

void main() {
  test('mushafPaper round-trips through map', () {
    const m = SettingsModel(isArabic: true, isFormat12Hours: false, mushafPaper: MushafPaper.night);
    final back = SettingsModel.fromMap(m.toMap());
    expect(back.mushafPaper, MushafPaper.night);
  });

  test('missing mushafPaper defaults to cream', () {
    final back = SettingsModel.fromMap({'isArabic': true});
    expect(back.mushafPaper, MushafPaper.cream);
  });
}
