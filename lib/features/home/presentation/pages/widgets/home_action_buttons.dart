import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_button.dart';

class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: HomeButton(
              title: 'القران',
              icon: HugeIcons.strokeRoundedQuran02,
              action: () {},
            ),
          ),
          Expanded(
            child: HomeButton(
              title: 'الحديث',
              icon: HugeIcons.strokeRoundedMuhammad,
              action: () {},
            ),
          ),
          Expanded(
            child: HomeButton(
              title: 'تصحيح القراءه',
              icon: HugeIcons.strokeRoundedTeaching,
              action: () {},
            ),
          ),
          Expanded(
            child: HomeButton(
              title: 'اشاره مرجعيه',
              icon: HugeIcons.strokeRoundedAllBookmark,
              action: () {},
            ),
          ),
        ],
      ),
    );
  }
}
