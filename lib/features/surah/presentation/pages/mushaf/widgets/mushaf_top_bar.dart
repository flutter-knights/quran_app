import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';

/// Slim frosted top bar shown with the Mushaf chrome: back, current surah,
/// and a tappable page indicator that opens the page-jump sheet. Pure
/// presentational — the parent supplies values + callbacks.
class MushafTopBar extends StatelessWidget {
  const MushafTopBar({
    super.key,
    required this.surahName,
    required this.pageNumber,
    required this.localeCode,
    required this.onBack,
    required this.onJump,
  });

  final String surahName;
  final int pageNumber;
  final String localeCode;
  final VoidCallback onBack;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final pageStr = pageNumber.toString().toIndicNumerals(localeCode);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 48,
          padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('mushaf-top-back'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  surahName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('mushaf-top-page'),
                onTap: onJump,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        pageStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
