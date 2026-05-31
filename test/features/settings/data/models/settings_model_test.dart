import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

void main() {
  group('SettingsModel.toMap', () {
    test('writes palette name, no isDarkMode key', () {
      const model = SettingsModel(
        isFormat12Hours: true,
        isArabic: false,
        palette: ColorPalette.slateDark,
      );
      final map = model.toMap();
      expect(map['palette'], 'slateDark');
      expect(map.containsKey('isDarkMode'), false);
    });
  });

  group('SettingsModel.fromMap', () {
    test('restores palette from name', () {
      final model = SettingsModel.fromMap({
        'isArabic': true,
        'isFormat12Hours': false,
        'palette': 'slateLight',
      });
      expect(model.palette, ColorPalette.slateLight);
    });

    test('defaults to neutralDark when palette key absent', () {
      final model = SettingsModel.fromMap({'isArabic': true, 'isFormat12Hours': true});
      expect(model.palette, ColorPalette.neutralDark);
    });

    test('ignores stale isDarkMode key without crashing', () {
      final model = SettingsModel.fromMap({
        'isArabic': true,
        'isFormat12Hours': true,
        'isDarkMode': true,
      });
      expect(model.palette, ColorPalette.neutralDark);
    });
  });

  group('round-trip', () {
    test('toMap then fromMap preserves all fields', () {
      const original = SettingsModel(
        isFormat12Hours: false,
        isArabic: true,
        palette: ColorPalette.neutralLight,
      );
      final restored = SettingsModel.fromMap(original.toMap());
      expect(restored.palette, original.palette);
      expect(restored.isFormat12Hours, original.isFormat12Hours);
      expect(restored.isArabic, original.isArabic);
    });
  });

  group('SettingsModel new mushaf fields', () {
    test('defaults: brightness 1.0, page mode, cream paper', () {
      const m = SettingsModel(isFormat12Hours: false, isArabic: true);
      expect(m.pageBrightness, 1.0);
      expect(m.readingMode, MushafReadingMode.page);
      expect(m.mushafPaper, MushafPaper.cream);
    });

    test('toMap/fromMap round-trips the new fields', () {
      const m = SettingsModel(
        isFormat12Hours: false,
        isArabic: true,
        pageBrightness: 0.6,
        readingMode: MushafReadingMode.scroll,
        mushafPaper: MushafPaper.night,
      );
      final back = SettingsModel.fromMap(m.toMap());
      expect(back.pageBrightness, 0.6);
      expect(back.readingMode, MushafReadingMode.scroll);
      expect(back.mushafPaper, MushafPaper.night);
    });

    test('fromMap clamps out-of-range brightness and defaults unknown mode', () {
      final m = SettingsModel.fromMap({
        'isArabic': true,
        'isFormat12Hours': false,
        'pageBrightness': 5.0, // too high
        'readingMode': 'bogus',
      });
      expect(m.pageBrightness, 1.0);
      expect(m.readingMode, MushafReadingMode.page);

      final low = SettingsModel.fromMap({
        'isArabic': true,
        'isFormat12Hours': false,
        'pageBrightness': 0.0,
      });
      expect(low.pageBrightness, 0.3);
    });
  });
}
