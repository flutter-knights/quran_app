import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/hadith_view.dart';

class HadithPage extends StatelessWidget {
  const HadithPage({super.key, required this.hadith, required this.bookSlug});
  final Hadith hadith;
  final String bookSlug;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<HadithBookmarkCubit>(),
      child: HadithView(hadith: hadith, bookSlug: bookSlug),
    );
  }
}
