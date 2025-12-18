import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'daily_prayer_context_state.dart';

class DailyPrayerContextCubit extends Cubit<DailyPrayerContextState> {
  DailyPrayerContextCubit() : super(DailyPrayerContextInitial());
}
