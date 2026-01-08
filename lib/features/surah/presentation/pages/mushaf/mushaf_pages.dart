import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';

class MushafPage extends StatefulWidget {
  final int pageNumber;
  const MushafPage({super.key, required this.pageNumber});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late PageController _pageController;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _pageController = PageController(initialPage: widget.pageNumber - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        reverse: context.isArabic ? false : true,
        itemCount: 604,
        itemBuilder: (context, index) {
          int pageNumber = index + 1;
          return BlocProvider(
            create: (_) => sl<MushafCubit>()..loadPage(pageNumber),
            child: MushafPageContent(pageNumber: pageNumber),
          );
        },
      ),
    );
  }
}
