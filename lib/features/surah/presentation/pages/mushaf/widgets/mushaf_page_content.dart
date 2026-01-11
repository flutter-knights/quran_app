import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import 'mushaf_layout.dart';

class MushafPageContent extends StatelessWidget {
  final int pageNumber;

  const MushafPageContent({super.key, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      builder: (context, state) {
        if (state is MushafLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MushafError) {
          return Center(child: Text(state.message));
        }

        if (state is MushafLoaded) {
          return MushafLayout(pageNumber: pageNumber, page: state.pageContent);
        }

        return const SizedBox();
      },
    );
  }
}
