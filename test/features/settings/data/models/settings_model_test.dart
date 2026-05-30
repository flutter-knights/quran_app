import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/color_palette.dart';
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

    test('notificationHintDismissed: defaults false and round-trips via map', () {
      const model = SettingsModel(isFormat12Hours: false, isArabic: true);
      expect(model.notificationHintDismissed, isFalse);

      final restored = SettingsModel.fromMap(
        model.copyWith(notificationHintDismissed: true).toMap(),
      );
      expect(restored.notificationHintDismissed, isTrue);
    });
  });
}
