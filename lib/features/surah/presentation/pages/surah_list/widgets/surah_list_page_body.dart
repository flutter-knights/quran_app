import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../../config/theme/typography_styles.dart';
import '../../../../../../core/constants/assets_dir.dart';
import '../../../../../../core/helper functions/locale_helpers.dart';
import '../../../../../../core/widgets/last_quran_read.dart';
import 'search_delegate.dart';
import 'surah_list_app_bar.dart';
import 'surah_search_bar.dart';

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
        SurahListSelection(),
      ],
    );
  }
}

class SurahListSelection extends StatelessWidget {
  const SurahListSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return SurahListTile(index: index + 1);
      }, childCount: 114),
    );
  }
}

class SurahListTile extends StatelessWidget {
  final int index;
  const SurahListTile({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: AspectRatio(
        aspectRatio: 5.1,

        child: Container(
          padding: .all(8),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainer,
            borderRadius: .all(Radius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Column(
                crossAxisAlignment: .start,
                textDirection: context.isArabic ? .rtl : .ltr,
                children: [
                  Text(
                    "سُورَةُ الفَاتِحَةِ",
                    style: TS.bold20,
                    overflow: .ellipsis,
                  ),
                  Gap(4),
                  Row(
                    spacing: 6,
                    children: [
                      Text(
                        "مكية",
                        style: TS.regular15.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      CirclerBullet(),
                      Text(
                        "7 آيات",
                        style: TS.regular15.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      CirclerBullet(),

                      Text(
                        "7 صفحة",
                        style: TS.regular15.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SurahNumberStar(surahNumber: index),
            ],
          ),
        ),
      ),
    );
  }
}

class SurahNumberStar extends StatelessWidget {
  const SurahNumberStar({super.key, required this.surahNumber});
  final int surahNumber;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SvgPicture.asset(
          AssetsDir.iconsDir('icon_star.svg'),
          colorFilter: .mode(context.colorScheme.onSurface, BlendMode.srcIn),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              surahNumber.toString(),
              style: TS.extra16.copyWith(color: context.colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}

class CirclerBullet extends StatelessWidget {
  const CirclerBullet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: context.colorScheme.onSurfaceVariant,
        shape: .circle,
      ),
    );
  }
}
