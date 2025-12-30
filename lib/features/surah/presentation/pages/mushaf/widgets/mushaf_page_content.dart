import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

import '../../../../data/datasources/mushaf_local_data_source.dart';
import '../../../../data/repositories/mushaf_repo_impl.dart';
import '../../../../domain/usecases/get_mushaf_page.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

class MushafPageContent extends StatelessWidget {
  final int pageNumber;

  const MushafPageContent({super.key, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MushafCubit(
        GetMushafPage(MushafRepositoryImpl(MushafLocalDataSource())),
      )..loadPage(pageNumber),
      child: BlocBuilder<MushafCubit, MushafState>(
        builder: (context, state) {
          if (state is MushafLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MushafError) {
            return Center(child: Text(state.message));
          }

          if (state is MushafLoaded) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMushafRichText(state.pageContent, pageNumber),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildMushafRichText(MushafPageEntity page, int pageIndex) {
    final List<InlineSpan> spans = [];

    int currentSurahIndex = 0;

    for (int i = 0; i < page.ayahs.length; i++) {
      // Insert surah header when needed
      if (page.surahHeadersIndexes.contains(i)) {
        final name = page.surahNames[currentSurahIndex];
        final basmala = page.showBasmalaList[currentSurahIndex];

        // Surah Name
        spans.add(
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: "QCF_P000",
                    fontSize: 42,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );

        // Basmala if needed
        if (basmala) {
          spans.add(
            const TextSpan(
              text: "\u0021\u0022\u0023\n",
              style: TextStyle(
                fontFamily: "QCF_P000",
                height: 1.5,
                fontSize: 26,
              ),
            ),
          );
        }

        currentSurahIndex++;
      }

      // Ayah text
      spans.add(
        TextSpan(
          locale: const Locale('ar'),
          text: page.ayahs[i],
          style: TextStyle(
            letterSpacing: 0.7,
            fontFamily: "QCF_P${pageIndex.toString().padLeft(3, "0")}",
            fontSize: 23,
            height: 1.95,
          ),
        ),
      );
    }

    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  // Widget _buildMushafRichText(MushafPageEntity page, int pageIndex) {
  //   final List<InlineSpan> spans = [];

  //   if (page.surahName != null) {
  //     spans.add(
  //       WidgetSpan(
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             Text(
  //               page.surahName!,
  //               textAlign: TextAlign.center,
  //               style: const TextStyle(fontFamily: "QCF_P000", fontSize: 42),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );

  //     // Add basmala except Surah 9
  //     if (page.showBasmala) {
  //       spans.add(
  //         const TextSpan(
  //           text: "\u0021\u0022\u0023\n", // Basmala characters
  //           style: TextStyle(
  //             fontFamily: "QCF_P000",
  //             fontSize: 28,
  //             fontWeight: FontWeight.w100,
  //           ),
  //         ),
  //       );
  //     }
  //   }

  //   // Add ayahs
  //   for (final ayah in page.ayahs) {
  //     spans.add(
  //       TextSpan(
  //         locale: const Locale('ar'),
  //         text: ayah,
  //         style: TextStyle(
  //           letterSpacing: 0.7,
  //           fontFamily: "QCF_P${pageIndex.toString().padLeft(3, "0")}",
  //           fontSize: 23,
  //           height: 1.95,
  //         ),
  //       ),
  //     );
  //   }

  //   return RichText(
  //     textDirection: TextDirection.rtl,
  //     textAlign: TextAlign.center,
  //     text: TextSpan(children: spans),
  //   );
  // }

  // Widget _buildMushafRichText(List<String> ayahs, int pageIndex) {
  //   return RichText(
  //     textDirection: TextDirection.rtl,
  //     textAlign: TextAlign.center,
  //     text: TextSpan(
  //       children: [
  //         for (final ayah in ayahs)
  //           TextSpan(
  //             locale: const Locale('ar'),
  //             text: ayah,

  //             style: TextStyle(
  //               letterSpacing: 0.7,
  //               fontFamily: "QCF_P${pageIndex.toString().padLeft(3, "0")}",
  //               fontSize: pageIndex == 1 || pageIndex == 2
  //                   ? 28
  //                   : pageIndex == 145 || pageIndex == 201
  //                   ? pageIndex == 532 || pageIndex == 533
  //                         ? 22.5
  //                         : 22.4
  //                   : 23,
  //               height: 1.95,
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }
}
