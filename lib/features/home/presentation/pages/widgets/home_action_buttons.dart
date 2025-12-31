import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';

import 'package:quran_app/features/home/presentation/pages/widgets/home_button.dart';

class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({super.key});

  void onPressed(BuildContext context, {required String path}) {
    GoRouter.of(context).push(path);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: HomeButton(
              title: 'القران',
              icon: HugeIcons.strokeRoundedQuran02,
              action: () {
                onPressed(context, path: AppRouter.surahListPath);
              },
            ),
          ),
          Expanded(
            child: HomeButton(
              title: 'الحديث',
              icon: HugeIcons.strokeRoundedMuhammad,
              action: () => onPressed(context, path: AppRouter.booksPath),
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
