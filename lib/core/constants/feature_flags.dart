/// Build-time flags that gate UI for in-progress features.
///
/// Once a feature's native side ships, flip its flag to `true` and remove
/// any conditional rendering that depended on it.
class FeatureFlags {
  const FeatureFlags._();

  /// Shows the "Pinned prayer times" toggle in the Settings sheet.
  /// Flip to `true` when Plan B (Android native pinned strip) lands.
  static const bool pinnedPrayerStripUi = false;
}
