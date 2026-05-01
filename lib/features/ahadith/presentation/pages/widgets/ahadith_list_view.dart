import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/custom_app_bar.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_search_delegate.dart';

class AhadithListView extends StatefulWidget {
  final String bookSlug;
  const AhadithListView({super.key, required this.bookSlug});

  @override
  State<AhadithListView> createState() => _AhadithListViewState();
}

class _AhadithListViewState extends State<AhadithListView> {
  late ScrollController _scrollController;
  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<AhadithCubit>().fetchAhadith(bookSlug: widget.bookSlug);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          // Controller stays here to track everything
          controller: _scrollController,
          slivers: [
            CustomAppBar(
              title: Text('اهلا'),
              isSliver: true,
              options: AppBarOptions(pinned: false, showBottomLine: false),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: AhadithSearchDelegate(
                height: 80,
                showBottomLine: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    decoration: InputDecoration(hintText: 'ابحث عن حديث'),
                  ),
                ),
              ),
            ),
            BlocBuilder<AhadithCubit, AhadithState>(
              builder: (context, state) {
                if (state is AhadithError) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('Error loading data')),
                  );
                }

                if (state is AhadithLoading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (state is AhadithLoaded || state is AhadithLoadingMore) {
                  final List<Hadith> ahadith = (state is AhadithLoaded)
                      ? state.ahadith
                      : (state as AhadithLoadingMore).oldAhadith;
                  final bool lastPage = (state is AhadithLoaded)
                      ? state.lastPage
                      : false;

                  return SliverMainAxisGroup(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: AhadithListItem(hadith: ahadith[index]),
                            ),
                            childCount: ahadith.length,
                          ),
                        ),
                      ),
                      if (!lastPage)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),
          ],
        ),
      ),
    );
  }
}
