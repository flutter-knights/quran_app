import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/search_hadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart';

class AhadithListPage extends StatelessWidget {
  final String bookSlug;
  const AhadithListPage({super.key, required this.bookSlug});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              sl<AhadithCubit>()..fetchAhadith(bookSlug: bookSlug),
        ),
        BlocProvider(
          create: (context) =>
              sl<SearchHadithCubit>()..initializeArabicBookSearch(bookSlug),
        ),
      ],

      child: AhadithListView(bookSlug: bookSlug),
    );
  }
}
