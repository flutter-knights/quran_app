import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/reciter.dart';

class Settings extends Equatable {
  final bool isDarkMode;
  final bool isFormat12Hours;
  final bool isArabic;
  final double playbackSpeed;
  final Reciter defaultReciter;

  const Settings({
    required this.isDarkMode,
    required this.isFormat12Hours,
    required this.isArabic,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
  });

  Settings copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
  }) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
    );
  }

  @override
  List<Object?> get props =>
      [isArabic, isDarkMode, isFormat12Hours, playbackSpeed, defaultReciter];
}
