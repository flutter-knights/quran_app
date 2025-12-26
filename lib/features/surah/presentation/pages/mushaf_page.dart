import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_app/features/surah/presentation/pages/widgets/mushaf_page_content.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  @override
  void initState() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        // reverse: true,
        itemCount: 604,
        itemBuilder: (context, index) {
          int pageNumber = index + 1;
          return MushafPageContent(pageNumber: pageNumber);
        },
      ),
    );
  }
}
