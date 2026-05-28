import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_bar_center_title.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/last_read_card.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahListPageBody extends StatefulWidget {
  const SurahListPageBody({super.key});

  @override
  State<SurahListPageBody> createState() => _SurahListPageBodyState();
}

class _SurahListPageBodyState extends State<SurahListPageBody> {
  String _query = '';

  List<SurahEntity> _filter(List<SurahEntity> surahs) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return surahs;
    return surahs
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.englishName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  AppBarCenterTitle(
                    label: S.of(context).the_noble_quran,
                    title: S.of(context).surahs_appbar_title,
                  ),
                  const Spacer(),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SurahCubit, List<SurahEntity>>(
                builder: (context, surahs) {
                  final filtered = _filter(surahs);
                  final lastRead = LastReadCard.maybeBuild(context);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (lastRead != null) ...[
                          lastRead,
                          const SizedBox(height: 14),
                        ],
                        SurahSearchBar(
                          onChanged: (q) => setState(() => _query = q),
                        ),
                        const SizedBox(height: 14),
                        AppSectionHeader(
                          label: S.of(context).all_surahs,
                          trailing: Text(
                            S.of(context).surahs_count(
                                  filtered.length.toLocalized(context),
                                ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              SurahListTile(surah: filtered[i]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
