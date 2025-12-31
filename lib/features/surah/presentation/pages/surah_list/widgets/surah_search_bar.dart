import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

import 'surah_segment_selector.dart';

class SurahSearchBar extends StatelessWidget {
  const SurahSearchBar({super.key, required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Gap(12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  onSubmitted: (value) {},
                  textInputAction: TextInputAction.search,
                  keyboardType: TextInputType.text,
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: IconButton(
                      onPressed: () {},
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01),
                    ),
                    hintText: "البحث عن سورة  ...",
                  ),
                  onChanged: (value) {},
                ),
              ),
            ),
          ],
        ),
        Gap(16),
        SurahSegmentSelector(),
      ],
    );
  }
}
