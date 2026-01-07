import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/surah_entity.dart';
import '../../../cubit/surah/surah_cubit.dart';
import 'surah_list_tile.dart';

class SurahSelectionList extends StatelessWidget {
  const SurahSelectionList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SurahCubit, List<SurahEntity>>(
      builder: (context, surahs) {
        return SliverList.builder(
          itemCount: surahs.length,
          itemBuilder: (context, index) {
            final surah = surahs[index];
            return SurahListTile(surah: surah);
          },
        );
      },
    );
  }
}
