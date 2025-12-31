import 'package:flutter/material.dart';

import 'widgets/surah_list_page_body.dart';

class SurahListPage extends StatelessWidget {
  const SurahListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SurahListPageBody(),
        ),
      ),
    );
  }
}
