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

String toAsciiDigits(String input) {
  final out = StringBuffer();
  for (final code in input.codeUnits) {
    if (code >= 0x0660 && code <= 0x0669) {
      out.writeCharCode(code - 0x0660 + 0x30);
    } else if (code >= 0x06F0 && code <= 0x06F9) {
      out.writeCharCode(code - 0x06F0 + 0x30);
    } else {
      out.writeCharCode(code);
    }
  }
  return out.toString();
}
