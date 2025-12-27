import 'package:equatable/equatable.dart';

class Settings extends Equatable {
  final bool isDarkMode;
  final bool isFormat12Hours;
  final bool isArabic;

  const Settings({
    required this.isDarkMode,
    required this.isFormat12Hours,
    required this.isArabic,
  });

  Settings copyWith({bool? isDarkMode, bool? isFormat12Hours, bool? isArabic}) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
    );
  }

  @override
  List<Object?> get props => [isArabic, isDarkMode, isFormat12Hours];
}
