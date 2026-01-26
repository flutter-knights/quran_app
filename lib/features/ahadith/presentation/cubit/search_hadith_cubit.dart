import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

part 'search_hadith_state.dart';

class SearchHadithCubit extends Cubit<SearchHadithState> {
  SearchHadithCubit() : super(SearchHadithInitial());
}
