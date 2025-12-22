import 'package:flutter/material.dart';

extension LocalizationExtension on Object {
  /// The universal "Arabic Numbers" converter for any object (int, String, etc.)
  String toLocalized(BuildContext context) {
    String input = toString();
    if (Localizations.localeOf(context).languageCode != 'ar') return input;

    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }
}

extension ContextLocaleExtension on BuildContext {
  /// Shortcut to check if the app is currently in Arabic
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  /// Shortcut to get the language code string
  String get langCode => Localizations.localeOf(this).languageCode;
}
