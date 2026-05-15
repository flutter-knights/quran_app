import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import 'widgets/mushaf_page_number_text.dart';
import 'widgets/mushaf_page_view.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.initialPage});
  final int initialPage;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    // RTL paging: index 0 = page 604, index 603 = page 1.
    _controller = PageController(initialPage: 604 - widget.initialPage);
    _controller.addListener(_precacheNeighbours);
  }

  @override
  void dispose() {
    _controller.removeListener(_precacheNeighbours);
    _controller.dispose();
    super.dispose();
  }

  int _pageNumberFor(int index) => 604 - index;

  void _precacheNeighbours() {
    final idx = _controller.page?.round();
    if (idx == null) return;
    for (final neighbour in [idx - 1, idx + 1]) {
      if (neighbour < 0 || neighbour > 603) continue;
      final page = _pageNumberFor(neighbour);
      precacheImage(
        AssetImage(
            'assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png'),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: 604,
                onPageChanged: (i) =>
                    context.read<MushafCubit>().setPage(_pageNumberFor(i)),
                itemBuilder: (_, i) =>
                    MushafPageView(pageNumber: _pageNumberFor(i)),
              ),
            ),
            BlocBuilder<MushafCubit, MushafState>(
              buildWhen: (a, b) => a.currentPage != b.currentPage,
              builder: (context, state) =>
                  MushafPageNumberText(pageNumber: state.currentPage),
            ),
          ],
        ),
      ),
    );
  }
}
