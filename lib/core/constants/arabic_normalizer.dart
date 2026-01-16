class ArabicNormalizer {
  static final RegExp _diacriticsRegex = RegExp(
    r'[\u064B-\u0652\u06D6-\u06ED\u0640]',
  );
  static String clean(String input) {
    if (input.isEmpty) return input;
    String result = input.replaceAll(_diacriticsRegex, '');
    result = result.replaceAll(RegExp(r'[أإآ]'), 'ا');
    result = result.replaceAll('ة', 'ه');
    result = result.replaceAll('ى', 'ي');

    return result.trim();
  }
}
