part of 'daily_hadith_cubit.dart';

sealed class DailyHadithState extends Equatable {
  const DailyHadithState();

  @override
  List<Object?> get props => [];
}

final class DailyHadithLoading extends DailyHadithState {
  const DailyHadithLoading();
}

final class DailyHadithLoaded extends DailyHadithState {
  const DailyHadithLoaded({required this.hadith, required this.bookSlug});
  final Hadith hadith;
  final String bookSlug;

  @override
  List<Object?> get props => [hadith.hadithNumber, bookSlug];
}

/// Resolved to nothing usable (offline on first run, API error). The home card
/// hides itself in this state rather than showing an error.
final class DailyHadithUnavailable extends DailyHadithState {
  const DailyHadithUnavailable();
}
