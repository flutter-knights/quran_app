import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';

part 'search_hadith_state.dart';

class SearchHadithCubit extends Cubit<SearchHadithState> {
  final DownloadBookCubit downloadBookCubit;
  SearchHadithCubit(this.downloadBookCubit) : super(SearchHadithInitial());

  


}
