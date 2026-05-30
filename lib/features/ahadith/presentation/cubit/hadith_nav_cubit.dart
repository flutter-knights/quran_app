import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_previous_hadith.dart';

part 'hadith_nav_state.dart';

/// Drives previous/next/swipe navigation inside the hadith page. Prefetches the
/// neighbors of the current hadith so a button tap or swipe is instant; if a
/// neighbor isn't ready yet it fetches on demand with a brief loading flag.
class HadithNavCubit extends Cubit<HadithNavState> {
  HadithNavCubit({
    required this.getNextHadith,
    required this.getPreviousHadith,
    required Hadith initial,
    required String bookSlug,
  }) : super(HadithNavState(current: initial, bookSlug: bookSlug)) {
    _prefetch();
  }

  final GetNextHadith getNextHadith;
  final GetPreviousHadith getPreviousHadith;

  Future<void> _prefetch() async {
    final current = state.current;
    final results = await Future.wait([
      getNextHadith.call(
        bookSlug: state.bookSlug,
        currentHadithNumber: current.hadithNumber,
      ),
      getPreviousHadith.call(
        bookSlug: state.bookSlug,
        currentHadithNumber: current.hadithNumber,
      ),
    ]);
    if (isClosed || state.current.hadithNumber != current.hadithNumber) return;

    final next = results[0].fold((_) => null, (h) => h);
    final previous = results[1].fold((_) => null, (h) => h);
    emit(state.withNeighbors(
      previous: previous,
      next: next,
      // Only mark a boundary when the lookup succeeded and returned null.
      atEnd: results[0].fold((_) => false, (h) => h == null),
      atStart: results[1].fold((_) => false, (h) => h == null),
    ));
  }

  Future<void> goNext() => _navigate(
        direction: 1,
        prefetched: state.next,
        blocked: state.atEnd,
        fetch: () => getNextHadith.call(
          bookSlug: state.bookSlug,
          currentHadithNumber: state.current.hadithNumber,
        ),
        markBoundary: (s) => s.withNeighbors(
          previous: s.previous,
          next: s.next,
          atStart: s.atStart,
          atEnd: true,
        ),
      );

  Future<void> goPrevious() => _navigate(
        direction: -1,
        prefetched: state.previous,
        blocked: state.atStart,
        fetch: () => getPreviousHadith.call(
          bookSlug: state.bookSlug,
          currentHadithNumber: state.current.hadithNumber,
        ),
        markBoundary: (s) => s.withNeighbors(
          previous: s.previous,
          next: s.next,
          atStart: true,
          atEnd: s.atEnd,
        ),
      );

  Future<void> _navigate({
    required int direction,
    required Hadith? prefetched,
    required bool blocked,
    required Future<Either<Failure, Hadith?>> Function() fetch,
    required HadithNavState Function(HadithNavState) markBoundary,
  }) async {
    if (blocked || state.loading) return;

    if (prefetched != null) {
      _setCurrent(prefetched, direction);
      return;
    }

    // Neighbor not prefetched yet — fetch on demand.
    emit(state.loadingState(true));
    final result = await fetch();
    if (isClosed) return;
    result.fold(
      (_) => emit(state.loadingState(false)),
      (hadith) {
        if (hadith == null) {
          emit(markBoundary(state.loadingState(false)));
        } else {
          _setCurrent(hadith, direction);
        }
      },
    );
  }

  void _setCurrent(Hadith hadith, int direction) {
    emit(HadithNavState(
      current: hadith,
      bookSlug: state.bookSlug,
      navDirection: direction,
    ));
    _prefetch();
  }
}
