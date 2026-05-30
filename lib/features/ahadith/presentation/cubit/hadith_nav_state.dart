part of 'hadith_nav_cubit.dart';

class HadithNavState extends Equatable {
  const HadithNavState({
    required this.current,
    required this.bookSlug,
    this.previous,
    this.next,
    this.atStart = false,
    this.atEnd = false,
    this.loading = false,
    this.navDirection = 0,
  });

  /// The hadith currently shown.
  final Hadith current;
  final String bookSlug;

  /// Prefetched neighbors — null until resolved (or genuinely absent).
  final Hadith? previous;
  final Hadith? next;

  /// Set once a lookup confirms there is no neighbor in that direction.
  final bool atStart;
  final bool atEnd;

  /// A blocking navigation fetch is in flight (neighbor wasn't prefetched yet).
  final bool loading;

  /// Direction of the last navigation that produced [current]: 1 = next,
  /// -1 = previous, 0 = initial. Drives the swap animation's slide direction.
  final int navDirection;

  bool get canGoNext => !atEnd;
  bool get canGoPrevious => !atStart;

  HadithNavState withNeighbors({
    Hadith? previous,
    Hadith? next,
    required bool atStart,
    required bool atEnd,
  }) =>
      HadithNavState(
        current: current,
        bookSlug: bookSlug,
        previous: previous,
        next: next,
        atStart: atStart,
        atEnd: atEnd,
        loading: false,
        navDirection: navDirection,
      );

  HadithNavState loadingState(bool value) => HadithNavState(
        current: current,
        bookSlug: bookSlug,
        previous: previous,
        next: next,
        atStart: atStart,
        atEnd: atEnd,
        loading: value,
        navDirection: navDirection,
      );

  @override
  List<Object?> get props => [
        current.hadithNumber,
        bookSlug,
        previous,
        next,
        atStart,
        atEnd,
        loading,
        navDirection,
      ];
}
