import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import '../../../domain/entities/surah_entity.dart';
import '../../../domain/usecases/get_surah_list.dart';

class SurahCubit extends Cubit<List<SurahEntity>> {
  final GetSurahList getSurahList;

  SurahCubit(this.getSurahList) : super([]);

  Future<void> fetchSurahs() async {
    final result = await getSurahList.call(NoParams());
    emit(result);
  }
}
