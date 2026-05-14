import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import 'mushaf_layout.dart';

class MushafPageContent extends StatelessWidget {
  const MushafPageContent({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      builder: (context, state) {
        return switch (state) {
          MushafInitial() => const SizedBox(),
          MushafLoading() => const Center(child: CircularProgressIndicator()),
          MushafError(:final message) => Center(child: Text(message)),
          MushafLoaded() => MushafLayout(pageNumber: pageNumber, loaded: state),
        };
      },
    );
  }
}
