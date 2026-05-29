import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart';
import 'package:quran_app/core/widgets/design/app_list_skeleton.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/books_list_view.dart';
import 'package:quran_app/generated/l10n.dart';

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

  String _bookTitle(BuildContext context) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == widget.bookSlug) return b.title;
    }
    return widget.bookSlug;
  }

  int? _bookHadithCount(BuildContext context) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == widget.bookSlug) return b.hadithCount;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(
              label: S.of(context).hadith_screen_title,
              title: _bookTitle(context),
            ),
            Expanded(
              child: BlocBuilder<AhadithCubit, AhadithState>(
                builder: (context, state) {
                  if (state is AhadithError) {
                    return const Center(child: Text('error'));
                  }
                  if (state is AhadithLoading) {
                    return const AppListSkeleton();
                  }
                  if (state is AhadithLoaded || state is AhadithLoadingMore) {
                    final List<Hadith> ahadith = (state is AhadithLoaded)
                        ? state.ahadith
                        : (state as AhadithLoadingMore).oldAhadith;
                    final bool lastPage = (state is AhadithLoaded)
                        ? state.lastPage
                        : false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: AppSectionHeader(
                            label: S.of(context).ahadith_section,
                            trailing: Text(
                              S
                                  .of(context)
                                  .ahadith_count(
                                    (_bookHadithCount(context) ??
                                            ahadith.length)
                                        .toLocalized(context),
                                  ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.secondary,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: lastPage
                                ? ahadith.length
                                : ahadith.length + 1,
                            cacheExtent: 400,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index >= ahadith.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return AhadithListItem(
                                hadith: ahadith[index],
                                bookSlug: widget.bookSlug,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
