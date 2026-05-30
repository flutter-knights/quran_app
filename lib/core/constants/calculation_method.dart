/// Aladhan calculation methods. `aladhanId` maps to the API's `method` param.
/// `auto` is a sentinel: resolve it to a concrete method via
/// `calculationMethodForCountry` before calling the API.
enum CalculationMethod {
  auto(null),
  karachi(1),
  isna(2),
  mwl(3),
  ummAlQura(4),
  egypt(5),
  tehran(7),
  gulf(8),
  kuwait(9),
  qatar(10),
  singapore(11),
  france(12),
  turkey(13),
  russia(14);

  const CalculationMethod(this.aladhanId);

  /// `null` only for [auto]; concrete methods always have an id.
  final int? aladhanId;
}

/// Asr juristic method. Maps to the Aladhan API's `school` param.
enum AsrSchool {
  shafi(0),
  hanafi(1);

  const AsrSchool(this.aladhanId);

  final int aladhanId;
}
