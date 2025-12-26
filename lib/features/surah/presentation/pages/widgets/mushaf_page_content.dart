import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/datasources/mushaf_local_data_source.dart';
import '../../../data/repositories/mushaf_repo_impl.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';

class MushafPageContent extends StatelessWidget {
  final int pageNumber;

  const MushafPageContent({super.key, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MushafCubit(
        GetMushafPage(MushafRepositoryImpl(MushafLocalDataSource())),
      )..loadPage(pageNumber),
      child: BlocBuilder<MushafCubit, MushafState>(
        builder: (context, state) {
          if (state is MushafLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MushafError) {
            return Center(child: Text(state.message));
          }

          if (state is MushafLoaded) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMushafRichText(state.page.ayahs, pageNumber),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildMushafRichText(List<String> ayahs, int pageIndex) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          for (final ayah in ayahs)
            TextSpan(
              locale: const Locale('ar'),
              text: ayah,

              style: TextStyle(
                letterSpacing: 0.7,
                fontFamily: "QCF_P${pageIndex.toString().padLeft(3, "0")}",
                fontSize: pageIndex == 1 || pageIndex == 2
                    ? 28
                    : pageIndex == 145 || pageIndex == 201
                    ? pageIndex == 532 || pageIndex == 533
                          ? 22.5
                          : 22.4
                    : 23,
                height: 1.95,
              ),
            ),
        ],
      ),
    );
  }
}
