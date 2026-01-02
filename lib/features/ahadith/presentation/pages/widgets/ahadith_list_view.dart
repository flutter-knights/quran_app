import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';

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
        child: BlocBuilder<AhadithCubit, AhadithState>(
          builder: (context, state) {
            if (state is AhadithError) {
              return const Center(child: Text('error'));
            }
            if (state is AhadithLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AhadithLoaded || state is AhadithLoadingMore) {
              final List<Hadith> ahadith = (state is AhadithLoaded)
                  ? state.ahadith
                  : (state as AhadithLoadingMore).oldAhadith;
              final bool lastPage = (state is AhadithLoaded)
                  ? state.lastPage
                  : false;
              return ListView.builder(
                controller: _scrollController,
                itemCount: lastPage ? ahadith.length : ahadith.length + 1,
                cacheExtent: 400,
                itemBuilder: (context, index) {
                  if (index >= ahadith.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final hadith = ahadith[index];
                  return SizedBox(child: Text(hadith.arabicHadith));
                },
              );
            }
            return SizedBox();
          },
        ),
      ),
    );
  }
}
