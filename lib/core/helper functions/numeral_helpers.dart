extension NumeralExtension on String {
  /// Pure-Dart Arabic-Indic numeral conversion.
  /// Returns `this` unchanged unless [localeCode] is `'ar'`.
  /// Used by domain-layer code that has no `BuildContext`.
  String toIndicNumerals(String localeCode) {
    if (localeCode != 'ar') return this;
    const ascii = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const indic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var out = this;
    for (var i = 0; i < ascii.length; i++) {
      out = out.replaceAll(ascii[i], indic[i]);
    }
    return out;
  }
}
