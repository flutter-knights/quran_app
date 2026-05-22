import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isDarkMode,
    required super.isFormat12Hours,
    required super.isArabic,
    super.playbackSpeed,
    super.defaultReciter,
    super.isPrayerStripPinned,
  });

  @override
  SettingsModel copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
    );
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isArabic: map['isArabic'] ?? true,
      isDarkMode: map['isDarkMode'] ?? true,
      isFormat12Hours: map['isFormat12Hours'] ?? true,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultReciter: Reciter.values.firstWhere(
        (r) => r.name == (map['defaultReciter'] as String?),
        orElse: () => Reciter.alafasy,
      ),
      isPrayerStripPinned: map['isPrayerStripPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isDarkMode': isDarkMode,
      'isFormat12Hours': isFormat12Hours,
      'playbackSpeed': playbackSpeed,
      'defaultReciter': defaultReciter.name,
      'isPrayerStripPinned': isPrayerStripPinned,
    };
  }
}
