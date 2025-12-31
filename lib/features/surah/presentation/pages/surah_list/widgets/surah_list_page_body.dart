import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../../core/widgets/last_quran_read.dart';
import 'search_delegate.dart';
import 'surah_list_app_bar.dart';
import 'surah_search_bar.dart';
import 'surah_selection_list.dart';

class SurahListPageBody extends StatefulWidget {
  const SurahListPageBody({super.key});

  @override
  State<SurahListPageBody> createState() => _SurahListPageBodyState();
}

class _SurahListPageBodyState extends State<SurahListPageBody> {
  late TextEditingController searchController;
  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();

    // searchController = TextEditingController(    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SurahListPageAppBar(),
        SliverToBoxAdapter(child: Gap(16)),
        SliverToBoxAdapter(child: LastQuranRead()),
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchDelegateBehavior(
            maxHeight: 126,
            minHeight: 126,

            child: SurahSearchBar(searchController: searchController),
          ),
        ),
        SliverToBoxAdapter(child: Gap(8)),
        SurahSelectionList(),
      ],
    );
  }
}
