import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isDarkMode,
    required super.isFormat12Hours,
    required super.isArabic,
  });

  @override
  SettingsModel copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
    );
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isArabic: map['isArabic'] ?? true,
      isDarkMode: map['isDarkMode'] ?? true,
      isFormat12Hours: map['isFormat12Hours'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isDarkMode': isDarkMode,
      'isFormat12Hours': isFormat12Hours,
    };
  }
}
