import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_daily_hadith.dart';

part 'daily_hadith_state.dart';

class DailyHadithCubit extends Cubit<DailyHadithState> {
  DailyHadithCubit({required this.getDailyHadith})
      : super(const DailyHadithLoading());

  final GetDailyHadith getDailyHadith;

  Future<void> load() async {
    emit(const DailyHadithLoading());
    final result = await getDailyHadith.call(DateTime.now().toUtc());
    if (isClosed) return;
    result.fold(
      (failure) => emit(const DailyHadithUnavailable()),
      (data) =>
          emit(DailyHadithLoaded(hadith: data.hadith, bookSlug: data.bookSlug)),
    );
  }
}
