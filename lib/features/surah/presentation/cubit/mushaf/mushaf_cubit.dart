import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_mushaf_page.dart';
import 'mushaf_state.dart';

class MushafCubit extends Cubit<MushafState> {
  final GetMushafPage useCase;

  MushafCubit(this.useCase) : super(MushafInitial());

  Future<void> loadPage(int pageNumber) async {
    emit(MushafLoading());

    try {
      final pageContent = await useCase.call(pageNumber);
      emit(MushafLoaded(pageContent));
    } catch (e) {
      emit(MushafError(e.toString()));
    }
  }
}
